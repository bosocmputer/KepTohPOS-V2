// Expected numbers in this test file were generated directly from the JS
// reference implementation in `prototype/index.html` (lines 450-763) +
// `prototype/data/mock-data.js` executed via Node.js (`node -e`) with fixed
// timestamp `new Date(2026, 10, 4, 12, 0, 0, 0)` and `rng(20261103)`.
import 'dart:convert';
import 'dart:io';

import 'package:app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

PosState _loadSeededState(DateTime fixedNow) {
  Map<String, dynamic> readObj(String name) =>
      jsonDecode(File('assets/mock/$name.json').readAsStringSync())
          as Map<String, dynamic>;
  List<Map<String, dynamic>> readList(String name) => (jsonDecode(
    File('assets/mock/$name.json').readAsStringSync(),
  ) as List<dynamic>).cast<Map<String, dynamic>>();

  return seed(
    shop: ShopConfig.fromJson(readObj('shop')),
    packages: readList('packages').map(PackageItem.fromJson).toList(),
    addons: readList('addons').map(AddonItem.fromJson).toList(),
    suppliers: readList('suppliers').map(SupplierItem.fromJson).toList(),
    ingredients: readList('ingredients').map(IngredientItem.fromJson).toList(),
    tables: readList('tables').map(DiningTable.fromJson).toList(),
    staff: readList('staff').map(StaffMember.fromJson).toList(),
    payments: readList('payments').map(PaymentMethod.fromJson).toList(),
    expenseTypes: readList('expense_types').map(ExpenseType.fromJson).toList(),
    fixedCosts: readList('fixed_costs').map(FixedCostItem.fromJson).toList(),
    now: fixedNow,
  );
}

void main() {
  group('rng(20261103) & seed() deterministic parity with JS', () {
    test(
      'rng(20261103) produces identical 32-bit float sequence as Math.imul',
      () {
        final rand = rng(20261103);
        final seq = List<double>.generate(5, (_) => rand());
        expect(seq[0], closeTo(0.24271581135690212, 1e-15));
        expect(seq[1], closeTo(0.5461220773868263, 1e-15));
        expect(seq[2], closeTo(0.7796479605603963, 1e-15));
        expect(seq[3], closeTo(0.4907275587320328, 1e-15));
        expect(seq[4], closeTo(0.47656899760477245, 1e-15));
      },
    );

    test('seed() produces exact row counts, totals, and open tables', () {
      final fixedNow = DateTime(2026, 11, 4, 12);
      final s = migrate(_loadSeededState(fixedNow));

      expect(s.version, 2);
      expect(s.startDate, '2026-10-05');
      expect(s.sales.length, 882);
      expect(s.purchases.length, 124);
      expect(s.expenses.length, 73);
      expect(s.shifts.length, 31);
      expect(s.counts.length, 30);
      expect(
        s.openTables.keys.toList(),
        equals(['t1', 't3', 't6', 't10', 't4']),
      );

      final totalSalesGross = s.sales.fold<double>(
        0,
        (acc, b) => acc + b.total,
      );
      final totalPurchasesValue = s.purchases.fold<double>(
        0,
        (acc, p) => acc + p.lines.fold<double>(0, (x, l) => x + l.total),
      );
      final totalExpensesAmount = s.expenses.fold<double>(
        0,
        (acc, e) => acc + e.amount,
      );

      expect(r2(totalSalesGross), 868006);
      expect(r2(totalPurchasesValue), 253628);
      expect(r2(totalExpensesAmount), 7720);

      final ot4 = s.openTables['t4']!;
      expect(tableDue(s, ot4), 886);
      final timer4 = tableTimer(s, ot4, now: fixedNow);
      expect(timer4.mins, 38);
      expect(timer4.limit, 0);
      expect(timer4.late, isFalse);
      expect(timer4.text, 'นั่งมา 38 น.');
    });
  });

  group('computeLedger parity (childHeadWeight, avg/last cost, netProfit)', () {
    test(
      'childHeadWeight 0.5 vs 1.0 changes headsW and costPerHead on day 0',
      () {
        final fixedNow = DateTime(2026, 11, 4, 12);
        final s = _loadSeededState(fixedNow);
        final ledHalf = computeLedger(s, today: '2026-11-04');
        expect(ledHalf.days.length, 31);

        final day0Half = ledHalf.days.first;
        expect(day0Half.date, '2026-10-05');
        expect(day0Half.a, 85);
        expect(day0Half.c, 7);
        expect(day0Half.f, 3);
        expect(day0Half.heads, 92);
        expect(day0Half.headsW, 88.5);
        expect(r2(day0Half.ingCost!), 6754.55);
        expect(r2(day0Half.costPerHead!), 76.32);

        s.shop = s.shop.copyWith(childHeadWeight: 1);
        final day0Full = computeLedger(s, today: '2026-11-04').days.first;
        expect(day0Full.headsW, 92);
        expect(r2(day0Full.ingCost!), 6754.55);
        expect(r2(day0Full.costPerHead!), 73.42);
      },
    );

    test(
      'costMethod avg vs last and netProfit on last closed day (2026-11-03)',
      () {
        final fixedNow = DateTime(2026, 11, 4, 12);
        final s = _loadSeededState(fixedNow);
        final ledAvg = computeLedger(s, today: '2026-11-04');
        final closedAvg = ledAvg.days.where((d) => d.closed).toList();
        expect(closedAvg.length, 30);

        final lastAvg = closedAvg.last;
        expect(lastAvg.date, '2026-11-03');
        expect(lastAvg.gross, 28447);
        expect(lastAvg.net, 28447);
        expect(r2(lastAvg.buffetNet), 22727);
        expect(r2(lastAvg.addonNet), 5720);
        expect(lastAvg.addonCost, 3451);
        expect(lastAvg.headsW, 110);
        expect(r2(lastAvg.fixed), 1536.67);
        expect(lastAvg.expenses, 100);
        expect(lastAvg.estItems, 4);
        expect(r2(lastAvg.ingCost!), 8060.36);
        expect(r2(lastAvg.profit!), 16935.64);
        expect(r2(lastAvg.netProfit!), 15298.97);
        expect(r2(lastAvg.costPerHead!), 73.28);
        expect(r2(lastAvg.foodPct!), 35.47);

        s.shop = s.shop.copyWith(costMethod: 'last');
        final lastLatest = computeLedger(
          s,
          today: '2026-11-04',
        ).days.where((d) => d.closed).last;
        expect(r2(lastLatest.ingCost!), 8068.89);
        expect(r2(lastLatest.profit!), 16927.11);
        expect(r2(lastLatest.netProfit!), 15290.44);
      },
    );
  });
}
