import 'dart:convert';
import 'dart:io';

import 'package:app/core/data/local/shop_snapshot_store.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

PosState _seeded() {
  Map<String, dynamic> obj(String n) =>
      jsonDecode(File('assets/mock/$n.json').readAsStringSync())
          as Map<String, dynamic>;
  List<Map<String, dynamic>> list(String n) => (jsonDecode(
    File('assets/mock/$n.json').readAsStringSync(),
  ) as List<dynamic>).cast<Map<String, dynamic>>();
  return seed(
    shop: ShopConfig.fromJson(obj('shop')),
    packages: list('packages').map(PackageItem.fromJson).toList(),
    addons: list('addons').map(AddonItem.fromJson).toList(),
    suppliers: list('suppliers').map(SupplierItem.fromJson).toList(),
    ingredients: list('ingredients').map(IngredientItem.fromJson).toList(),
    tables: list('tables').map(DiningTable.fromJson).toList(),
    staff: list('staff').map(StaffMember.fromJson).toList(),
    payments: list('payments').map(PaymentMethod.fromJson).toList(),
    expenseTypes: list('expense_types').map(ExpenseType.fromJson).toList(),
    fixedCosts: list('fixed_costs').map(FixedCostItem.fromJson).toList(),
    now: DateTime(2026, 11, 4, 12),
  );
}

/// What `get_daily_sales_totals` returns for one day of non-voided bills.
DailySalesTotal _totalOf(List<BillRecord> bills) {
  var gross = 0.0;
  var net = 0.0;
  var buffet = 0.0;
  var addon = 0.0;
  var cost = 0.0;
  var a = 0;
  var c = 0;
  var f = 0;
  for (final b in bills) {
    gross += b.total;
    net += b.total - b.vat;
    a += b.heads.a;
    c += b.heads.c;
    f += b.heads.f;
    final k2 = b.subtotal != 0 ? (b.total - b.vat) / b.subtotal : 0.0;
    for (final l in b.lines) {
      if (l.type == 'addon') {
        addon += l.qty * l.price * k2;
        cost += l.qty * (l.cost ?? 0);
      } else {
        buffet += l.qty * l.price * k2;
      }
    }
  }
  return DailySalesTotal(
    bills: bills.length,
    a: a,
    c: c,
    f: f,
    gross: gross,
    net: net,
    buffetNet: buffet,
    addonNet: addon,
    addonCost: cost,
  );
}

/// Same state, but days before [rawFrom] come only from daily totals.
PosState _split(PosState full, String rawFrom) {
  final s = PosState.fromJson(full.toJson());
  final old = s.sales.where((b) => b.date.compareTo(rawFrom) < 0).toList();
  s.sales.removeWhere((b) => b.date.compareTo(rawFrom) < 0);
  s.rawFrom = rawFrom;
  final byDay = <String, List<BillRecord>>{};
  for (final b in old.where((b) => !b.voided)) {
    (byDay[b.date] ??= <BillRecord>[]).add(b);
  }
  s.dailyTotals.addAll(byDay.map((k, v) => MapEntry(k, _totalOf(v))));
  return s;
}

void main() {
  _addonMergeTest();
  const today = '2026-11-04';
  const rawFrom = '2026-11-01';

  test('rawFrom + dailyTotals gives the same ledger as full raw bills', () {
    // Arrange
    final full = _seeded();
    final split = _split(full, rawFrom);
    expect(full.sales.where((b) => b.date.compareTo(rawFrom) < 0), isNotEmpty);
    expect(split.sales.length, lessThan(full.sales.length));

    // Act
    final a = computeLedger(full, today: today);
    final b = computeLedger(PosState.fromJson(split.toJson()), today: today);

    // Assert
    expect(b.days.length, a.days.length);
    for (var i = 0; i < a.days.length; i++) {
      final x = a.days[i];
      final y = b.days[i];
      expect(y.date, x.date);
      expect(y.bills, x.bills, reason: x.date);
      expect([y.a, y.c, y.f], [x.a, x.c, x.f], reason: x.date);
      for (final p in <(double, double)>[
        (y.gross, x.gross),
        (y.net, x.net),
        (y.buffetNet, x.buffetNet),
        (y.addonNet, x.addonNet),
        (y.addonCost, x.addonCost),
        (y.fixed, x.fixed),
        (y.ingCost ?? 0, x.ingCost ?? 0),
        (y.netProfit ?? 0, x.netProfit ?? 0),
      ]) {
        expect(p.$1, closeTo(p.$2, 1e-6), reason: x.date);
      }
    }
  });

  test('an old day with no totals is a zero day; null addonCost is 0', () {
    // Arrange
    final s = _split(_seeded(), rawFrom);
    s.dailyTotals.remove('2026-10-10');
    final t = s.dailyTotals['2026-10-11']!;
    s.dailyTotals['2026-10-11'] = DailySalesTotal(
      bills: t.bills,
      a: t.a,
      c: t.c,
      f: t.f,
      gross: t.gross,
      net: t.net,
      buffetNet: t.buffetNet,
      addonNet: t.addonNet,
    );

    // Act
    final r = computeLedger(s, today: today);

    // Assert
    final zero = r.byDate['2026-10-10']!;
    expect([zero.bills, zero.gross, zero.net, zero.fixed], [0, 0, 0, 0]);
    expect(r.byDate['2026-10-11']!.addonCost, 0);
    expect(r.byDate['2026-10-11']!.gross, t.gross);
  });

  test('state without the new fields loads as all-raw and round-trips', () {
    // Arrange
    final json = _seeded().toJson()
      ..remove('rawFrom')
      ..remove('dailyTotals');

    // Act
    final s = PosState.fromJson(json);

    // Assert
    expect(s.rawFrom, isNull);
    expect(s.dailyTotals, isEmpty);
    final back = PosState.fromJson(_split(_seeded(), rawFrom).toJson());
    expect(back.rawFrom, rawFrom);
    expect(back.dailyTotals['2026-10-10']!.gross, greaterThan(0));
    expect(back.copy().dailyTotals.length, back.dailyTotals.length);
  });

  test('stripCosts nulls addonCost of every daily total', () {
    // Arrange
    final json = _split(_seeded(), rawFrom).toJson();
    final before = json['dailyTotals'] as Map<String, dynamic>;
    expect((before.values.first as Map)['addonCost'], isNotNull);

    // Act
    final stripped = stripCosts(json)['dailyTotals'] as Map<String, dynamic>;

    // Assert
    expect(stripped.length, before.length);
    for (final t in stripped.values) {
      expect((t as Map)['addonCost'], isNull);
      expect(t['gross'], isNotNull);
    }
  });
}

void _addonMergeTest() {
  const rawFrom = '2026-11-01';
  test('addon sales: rawFrom split with RPC rows == all-raw result', () {
    // Arrange
    final full = _seeded();
    final split = _split(full, rawFrom);
    // What get_addon_sales returns: per day and item, non-voided bills.
    final agg = <String, ({int q, double rev, double cost})>{};
    for (final b in full.sales.where(
      (b) => !b.voided && b.date.compareTo(rawFrom) < 0,
    )) {
      for (final l in b.lines.where((l) => l.type == 'addon')) {
        final k = '${b.date}|${l.name}';
        final p = agg[k] ?? (q: 0, rev: 0.0, cost: 0.0);
        agg[k] = (
          q: p.q + l.qty,
          rev: p.rev + l.qty * l.price,
          cost: p.cost + l.qty * (l.cost ?? 0),
        );
      }
    }
    expect(agg, isNotEmpty);
    split.addonSalesBefore.addAll([
      for (final e in agg.entries)
        AddonSaleDay(
          date: e.key.split('|')[0],
          name: e.key.split('|')[1],
          qty: e.value.q,
          rev: e.value.rev,
          cost: e.value.cost,
        ),
    ]);
    final restored = PosState.fromJson(split.toJson());

    // Act
    for (final range in ['month', '30']) {
      final a = computeDashboardSummary(
        full,
        computeLedger(full, today: '2026-11-04'),
        range: range,
        today: '2026-11-04',
      ).addonSales;
      final b = computeDashboardSummary(
        restored,
        computeLedger(restored, today: '2026-11-04'),
        range: range,
        today: '2026-11-04',
      ).addonSales;

      // Assert
      expect(b.length, a.length, reason: range);
      for (var i = 0; i < a.length; i++) {
        expect(b[i].name, a[i].name, reason: range);
        expect(b[i].qty, a[i].qty, reason: range);
        expect(b[i].rev, closeTo(a[i].rev, 1e-6), reason: range);
        expect(b[i].cost, closeTo(a[i].cost, 1e-6), reason: range);
      }
    }
    expect(
      stripCosts(restored.toJson())['addonSalesBefore'],
      everyElement(containsPair('cost', null)),
    );
  });
}
