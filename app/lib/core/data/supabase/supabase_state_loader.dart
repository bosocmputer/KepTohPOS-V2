import 'package:app/core/data/supabase/supabase_row_mappers.dart';
import 'package:app/domain/models.dart';
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

  Future<List<Row>> _all(String table, String columns, String orderBy) async {
    final rows = <Row>[];
    for (var from = 0; ; from += _kPageSize) {
      final page = await _client
          .from(table)
          .select(columns)
          .eq('shop_id', _shopId)
          .order(orderBy, ascending: true)
          .range(from, from + _kPageSize - 1);
      rows.addAll(page);
      if (page.length < _kPageSize) return rows;
    }
  }

  /// Loads the snapshot. [token] is the staff session; manager-only data is
  /// included only when the server accepts it, so a cashier gets none.
  Future<SupabaseSnapshot> load({
    required String currentStaffId,
    String? token,
    String? staffRole,
  }) async {
    final shop = await _client
        .from('shops')
        .select()
        .eq('id', _shopId)
        .single();
    final org = await _client
        .from('organizations')
        .select('id, tax_id')
        .eq('id', shop['org_id'] as String)
        .single();
    final startDate = (shop['created_at'] as String).substring(0, 10);

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
      _all('bills', '*', 'at'),
      _all(
        'bill_lines',
        'id, shop_id, bill_id, line_no, type, item_id, name, qty, price',
        'id',
      ),
      _all('shifts', '*', 'opened_at'),
      _all('stock_counts', '*', 'ingredient_id'),
      _all('table_sessions', '*', 'opened_at'),
      _all('table_rounds', '*', 'at'),
      _all('table_adjustments', '*', 'at'),
      _all('settled_table_events', '*', 'event_id'),
    ]);

    final manager = token != null && staffRole != 'cashier';
    final extra = manager
        ? await _client.rpc<Map<String, dynamic>>(
            'get_manager_data',
            params: <String, dynamic>{
              'p_shop_id': _shopId,
              'p_from': startDate,
              'p_to': DateTime.now()
                  .add(const Duration(days: 2))
                  .toIso8601String()
                  .substring(0, 10),
              'p_token': token,
            },
          )
        : const <String, dynamic>{};

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

    final open = _openTables(
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
      ),
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

  ({Map<String, OpenTableState> tables, Map<String, String> sessions})
  _openTables({
    required List<Row> sessions,
    required List<Row> rounds,
    required List<Row> adjustments,
    required Set<String> settled,
    required List<Row> bills,
  }) {
    final tables = <String, OpenTableState>{};
    final bySession = <String, String>{};
    for (final s in sessions.where((x) => x['closed_at'] == null)) {
      final id = s['id'] as String;
      final tableId = s['table_id'] as String;
      final sessionRounds = rounds.where((r) => r['session_id'] == id);
      final sessionAdjusts = adjustments.where((j) => j['session_id'] == id);
      final sessionBills = bills.where((b) => b['session_id'] == id);

      // Same running total as openOrAdd/adjustSent/voidBill in the domain.
      var a = 0;
      var c = 0;
      var f = 0;
      void add(Row r, int sign) {
        a += sign * (r['heads_a'] as int);
        c += sign * (r['heads_c'] as int);
        f += sign * (r['heads_f'] as int);
      }

      final isAfter = s['timing'] == 'after';
      if (isAfter) {
        for (final r in sessionRounds) {
          add(r, 1);
        }
        for (final j in sessionAdjusts.where((x) => x['kind'] == 'head')) {
          final qty = j['qty'] as int;
          switch (j['key']) {
            case 'a':
              a -= qty;
            case 'c':
              c -= qty;
            case 'f':
              f -= qty;
          }
        }
      } else {
        for (final b in sessionBills.where((x) => x['voided'] != true)) {
          add(b, 1);
        }
      }

      tables[tableId] = OpenTableState(
        openedAt: s['opened_at'] as String,
        packageId: s['package_id'] as String,
        timing: s['timing'] as String,
        notes: s['notes'] as String,
        billIds: sessionBills.map((b) => b['id'] as String).toList(),
        heads: HeadsCount(a: a < 0 ? 0 : a, c: c < 0 ? 0 : c, f: f < 0 ? 0 : f),
        rounds: sessionRounds
            .where((r) => !settled.contains(r['id']))
            .map(roundFromRow)
            .toList(),
        adjusts: sessionAdjusts
            .where((j) => !settled.contains(j['id']))
            .map(adjustmentFromRow)
            .toList(),
        log: sessionAdjusts
            .where((j) => settled.contains(j['id']))
            .map(adjustmentFromRow)
            .toList(),
      );
      bySession[tableId] = id;
    }
    return (tables: tables, sessions: bySession);
  }
}
