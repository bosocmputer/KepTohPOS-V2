import 'package:app/core/data/supabase/supabase_open_tables.dart';
import 'package:app/core/data/supabase/supabase_row_mappers.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/roles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const int _kPageSize = 1000;

/// Payment methods keep the order staff expect: cash first.
int _typeRank(String type) =>
    const <String>['cash', 'qr', 'transfer', 'card'].indexOf(type);

/// A loaded snapshot and the open table sessions behind it.
class SupabaseSnapshot {
  const new({
    required this.state,
    required this.sessionByTable,
    required this.organizationId,
    required this.canReadCosts,
  });

  final PosState state;

  /// Open `table_sessions.id` by table id. The domain has no session concept.
  final Map<String, String> sessionByTable;
  final String organizationId;
  final bool canReadCosts;
}

/// Loads a shop's whole state into a [PosState] for the existing domain code.
///
/// `computeLedger` needs the full history. Moving reports to SQL in phase F4
/// replaces this; the free-plan shops it serves are small until then.
class SupabaseStateLoader {
  const new(this._client, this._shopId);

  final SupabaseClient _client;
  final String _shopId;

  /// Pages through a table; [since] = (column, value) keeps `column >= value`.
  Future<List<Row>> _all(
    String table,
    String columns,
    String orderBy, {
    (String, String)? since,
  }) async {
    final rows = <Row>[];
    for (var from = 0; ; from += _kPageSize) {
      final q = _client.from(table).select(columns).eq('shop_id', _shopId);
      final page = await (since == null ? q : q.gte(since.$1, since.$2))
          .order(orderBy, ascending: true)
          .range(from, from + _kPageSize - 1);
      rows.addAll(page);
      if (page.length < _kPageSize) return rows;
    }
  }

  /// Loads the snapshot. [token] is the staff session; manager-only data is
  /// included only when the server accepts it; a cashier gets only today's
  /// purchases and expenses, without amounts.
  Future<SupabaseSnapshot> load({
    required String currentStaffId,
    String? token,
    bool readsCosts = false,
  }) async {
    final shop = await _client
        .from('shops')
        .select()
        .eq('id', _shopId)
        .single();
    final org = await _client
        .from('organizations')
        .select('id, tax_id, vat_registered')
        .eq('id', shop['org_id'] as String)
        .single();
    final startDate = (shop['created_at'] as String).substring(0, 10);
    // Raw bills only for the last 7 business days; older days are totals.
    final cutoff = (shop['day_cutoff_minutes'] as num?)?.toInt() ?? 0;
    final rawFrom = dkey(
      addDays(parseKey(businessDayKey(DateTime.now(), cutoff)), -6),
    );

    final results = await Future.wait(<Future<List<Row>>>[
      _all('bank_accounts', '*', 'id'),
      _all('packages', '*', 'name'),
      _all('addons', 'id, name, category, price, stock, active', 'name'),
      _all('suppliers', '*', 'name'),
      _all(
        'ingredients',
        'id, name, unit, par, supplier_id, category, use_per_head, location, '
            'count_freq',
        'id',
      ),
      _all('dining_tables', '*', 'name'),
      _all('staff', '*', 'name'),
      _all('payment_methods', '*', 'id'),
      _all('expense_types', '*', 'name'),
      _all('bills', '*', 'at', since: ('business_date', rawFrom)),
      _all(
        'bill_lines',
        'id, shop_id, bill_id, line_no, type, item_id, name, qty, price, '
            'bills!inner(business_date)',
        'id',
        since: ('bills.business_date', rawFrom),
      ),
      _all('shifts', '*', 'opened_at'),
      _all('stock_counts', '*', 'ingredient_id'),
      _all('table_sessions', '*', 'opened_at'),
      _all('table_rounds', '*', 'at'),
      _all('table_adjustments', '*', 'at'),
      _all('settled_table_events', '*', 'event_id'),
    ]);

    final manager = token != null && readsCosts;
    final extra = manager
        ? await _client.rpc<Map<String, dynamic>>(
            'get_manager_data',
            params: <String, dynamic>{
              'p_shop_id': _shopId,
              'p_from': rawFrom,
              'p_to': DateTime.now()
                  .add(const Duration(days: 2))
                  .toIso8601String()
                  .substring(0, 10),
              'p_token': token,
            },
          )
        // A cashier sees today's entries without amounts, to confirm saves.
        : token != null
        ? await _client.rpc<Map<String, dynamic>>(
            'get_day_entries',
            params: <String, dynamic>{'p_token': token},
          )
        : const <String, dynamic>{};

    final dailyTotals = rawFrom.compareTo(startDate) > 0
        ? await _dailyTotals(startDate, rawFrom, token)
        : const <String, DailySalesTotal>{};

    final addonSalesBefore = await _addonSalesBefore(startDate, rawFrom, token);
    List<Row> listOf(String key) =>
        ((extra[key] as List<dynamic>?) ?? const <dynamic>[]).cast<Row>();
    Map<String, int> costs(String key, String field) => <String, int>{
      for (final c in listOf(key)) c['id'] as String: (c[field] as num).toInt(),
    };
    final addonCosts = costs('addon_costs', 'cost');
    final ingredientCosts = costs('ingredient_costs', 'last_cost');
    final lineCosts = <String, int>{
      for (final c in listOf('bill_line_costs'))
        '${c['bill_id']}#${c['line_no']}': (c['cost'] as num).toInt(),
    };

    final linesByBill = <String, List<Row>>{};
    for (final l in results[10]) {
      (linesByBill[l['bill_id'] as String] ??= <Row>[]).add(l);
    }
    final bills = results[9].map((b) {
      final id = b['id'] as String;
      final lines = (linesByBill[id] ?? <Row>[])
        ..sort((x, y) => (x['line_no'] as int).compareTo(y['line_no'] as int));
      return billFromRow(
        b,
        lines
            .map((l) => lineFromRow(l, lineCosts['$id#${l['line_no']}']))
            .toList(),
      );
    }).toList();

    final counts = <String, Map<String, double>>{};
    for (final c in results[12]) {
      (counts[c['business_date'] as String] ??=
          <String, double>{})[c['ingredient_id'] as String] = (c['qty'] as num)
          .toDouble();
    }

    final open = openTablesFrom(
      sessions: results[13],
      rounds: results[14],
      adjustments: results[15],
      settled: results[16].map((e) => e['event_id'] as String).toSet(),
      bills: results[9],
    );

    final state = PosState(
      startDate: startDate,
      currentStaffId: currentStaffId,
      shop: shopFromRow(
        shop,
        (org['tax_id'] as String?) ?? '',
        results[0].map(bankFromRow).toList(),
      ).copyWith(vatRegistered: org['vat_registered'] as bool),
      packages: results[1].map(packageFromRow).toList(),
      addons: results[2]
          .map((r) => addonFromRow(r, addonCosts[r['id']] ?? 0))
          .toList(),
      suppliers: results[3].map(supplierFromRow).toList(),
      ingredients: results[4]
          .map((r) => ingredientFromRow(r, ingredientCosts[r['id']] ?? 0))
          .toList(),
      tables: results[5].map(tableFromRow).toList(),
      staff: results[6].map(staffFromRow).toList(),
      payments: results[7].map(paymentFromRow).toList()
        ..sort((x, y) => _typeRank(x.type).compareTo(_typeRank(y.type))),
      expenseTypes: results[8].map(expenseTypeFromRow).toList(),
      fixedCosts: listOf('fixed_costs').map(fixedCostFromRow).toList(),
      sales: bills,
      shifts: results[11].map(shiftFromRow).toList(),
      counts: counts,
      openTables: open.tables,
      expenses: listOf('expenses').map(expenseFromRow).toList(),
      rawFrom: rawFrom,
      dailyTotals: dailyTotals,
      addonSalesBefore: addonSalesBefore,
      purchases: listOf('purchases').map(purchaseFromRow).toList(),
      initialStock: <String, StockLot>{
        for (final l in listOf('initial_stock'))
          l['ingredient_id'] as String: StockLot(
            qty: (l['qty'] as num).toDouble(),
            cost: (l['cost'] as num).toInt(),
          ),
      },
    );

    return SupabaseSnapshot(
      state: state.copy().freeze(),
      sessionByTable: open.sessions,
      organizationId: org['id'] as String,
      canReadCosts: manager,
    );
  }

  /// Totals for [from] up to the day before [rawFrom], 400 days per call.
  Future<Map<String, DailySalesTotal>> _dailyTotals(
    String from,
    String rawFrom,
    String? token,
  ) async {
    final end = addDays(parseKey(rawFrom), -1);
    final out = <String, DailySalesTotal>{};
    for (var d = parseKey(from); !d.isAfter(end); d = addDays(d, 401)) {
      final to = addDays(d, 400).isAfter(end) ? end : addDays(d, 400);
      final rows = await _client.rpc<List<dynamic>>(
        'get_daily_sales_totals',
        params: <String, dynamic>{
          'p_shop_id': _shopId,
          'p_from': dkey(d),
          'p_to': dkey(to),
          'p_token': token,
        },
      );
      for (final r in rows.cast<Row>()) {
        out[r['business_date'] as String] = DailySalesTotal(
          bills: r['bills'] as int,
          a: r['a'] as int,
          c: r['c'] as int,
          f: r['f'] as int,
          gross: (r['gross'] as num).toDouble(),
          net: (r['net'] as num).toDouble(),
          buffetNet: (r['buffet_net'] as num).toDouble(),
          addonNet: (r['addon_net'] as num).toDouble(),
          addonCost: (r['addon_cost'] as num?)?.toDouble(),
        );
      }
    }
    return out;
  }

  /// Add-on sales the dashboard (month / 30 days) needs from before [rawFrom].
  Future<List<AddonSaleDay>> _addonSalesBefore(
    String startDate,
    String rawFrom,
    String? token,
  ) async {
    final today = parseKey(rawFrom).add(const Duration(days: 6));
    final monthStart = DateTime(today.year, today.month);
    final back30 = addDays(today, -29);
    var from = dkey(monthStart.isBefore(back30) ? monthStart : back30);
    if (from.compareTo(startDate) < 0) from = startDate;
    if (from.compareTo(rawFrom) >= 0) return const <AddonSaleDay>[];
    final rows = await _client.rpc<List<dynamic>>(
      'get_addon_sales',
      params: <String, dynamic>{
        'p_shop_id': _shopId,
        'p_from': from,
        'p_to': dkey(addDays(parseKey(rawFrom), -1)),
        'p_token': token,
      },
    );
    return [
      for (final r in rows.cast<Row>())
        AddonSaleDay(
          date: r['business_date'] as String,
          name: r['name'] as String,
          qty: (r['qty'] as num).toInt(),
          rev: (r['rev'] as num).toDouble(),
          cost: (r['cost'] as num?)?.toDouble(),
        ),
    ];
  }
}
