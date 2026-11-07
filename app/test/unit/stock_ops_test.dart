// Expected numbers in this test file were generated directly from the JS
// reference implementation in `prototype/index.html` (lines 450-763, 1313-1509)
// + `prototype/data/mock-data.js` executed via Node.js (`node`) with fixed
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
  const owner = StaffMember(
    id: 'st1',
    name: 'พี่ต้อม (เจ้าของร้าน)',
    role: 'owner',
    pin: '1111',
  );
  const cashier = StaffMember(
    id: 'st3',
    name: 'บีม (แคชเชียร์)',
    role: 'cashier',
    pin: '3333',
  );

  group('Discrete vs Continuous units & StockStatus (Rules 1A & 2A)', () {
    test(
      'isDiscreteUnit & roundQty round discrete units to integer and continuous'
      ' units to 1 decimal place',
      () {
        for (final u in <String>['ฟอง', 'แพ็ค', 'ถุง', 'ชิ้น', 'ขวด']) {
          expect(isDiscreteUnit(u), isTrue, reason: u);
          expect(roundQty(12.4, u), 12);
          expect(roundQty(12.5, u), 13);
        }
        for (final u in <String>['กก.', 'ลิตร']) {
          expect(isDiscreteUnit(u), isFalse, reason: u);
          expect(roundQty(10.16, u), 10.2);
          expect(roundQty(10.14, u), 10.1);
        }
      },
    );

    test('computeStockStatus evaluates out, low, and ok against par with '
        'par == 0 fallback', () {
      expect(computeStockStatus(0, 15), StockStatus.out);
      expect(computeStockStatus(-1, 15), StockStatus.out);
      expect(computeStockStatus(0.1, 15), StockStatus.low);
      expect(computeStockStatus(14.9, 15), StockStatus.low);
      expect(computeStockStatus(15, 15), StockStatus.ok);
      expect(computeStockStatus(20, 15), StockStatus.ok);

      // par == 0 edge case: out when qty <= 0, otherwise ok
      expect(computeStockStatus(0, 0), StockStatus.out);
      expect(computeStockStatus(1, 0), StockStatus.ok);
    });
  });

  group('saveDailyCount & reopenClosedDay JS parity', () {
    test('saveDailyCount rounds per unit, closes 2026-11-04, and updates '
        'ingCost / costPerHead / foodPct / profit / netProfit matching JS', () {
      final fixedNow = DateTime(2026, 11, 4, 12);
      final s = _loadSeededState(fixedNow);
      const today = '2026-11-04';

      final led0 = computeLedger(s, today: today);
      final d0 = led0.byDate[today]!;
      expect(d0.closed, isFalse);
      expect(d0.ingCost, isNull);
      expect(d0.netProfit, isNull);

      // Enter avail - 2.34 for all 11 due daily items (unrounded strings)
      final draft = <String, String>{};
      for (final r in d0.rows) {
        if (r.ing.countFreq != 'weekly') {
          final raw = (r.avail - 2.34).clamp(0.0, double.infinity);
          draft[r.ing.id] = raw.toStringAsFixed(2);
        }
      }
      expect(draft.length, 11);

      saveDailyCount(s, date: today, draftValues: draft);
      // i1 (กก., avail 12.5 -> 10.16) rounds to 10.2;
      // i10 (แพ็ค) & i12 (ฟอง) round to integers
      expect(s.counts[today]!['i1'], 10.2);
      expect(s.counts[today]!['i10'], s.counts[today]!['i10']!.roundToDouble());
      expect(s.counts[today]!['i12'], s.counts[today]!['i12']!.roundToDouble());

      final led1 = computeLedger(s, today: today);
      final d1 = led1.byDate[today]!;
      expect(d1.closed, isTrue);
      expect(r2(d1.ingCost! / 100), 3045.39);
      expect(r2(d1.costPerHead! / 100), 93.7);
      expect(r2(d1.foodPct!), 44.36);
      expect(r2(d1.profit! / 100), 4604.61);
      expect(r2(d1.netProfit! / 100), 2547.94);
      expect(r2(led1.current['i1']!.qty), 10.2);
      expect(r2(led1.current['i7']!.qty), 0.6);

      // Cashier cannot reopen a closed day; owner can
      expect(reopenClosedDay(s, date: today, me: cashier), isFalse);
      expect(s.counts.containsKey(today), isTrue);

      expect(reopenClosedDay(s, date: today, me: owner), isTrue);
      expect(s.counts.containsKey(today), isFalse);
      final ledReopened = computeLedger(s, today: today);
      expect(ledReopened.byDate[today]!.closed, isFalse);
      expect(r2(ledReopened.current['i1']!.qty), 12.5);
    });
  });

  group('savePurchase & costMethod avg vs last JS parity (Rule 3)', () {
    test(
      'savePurchase does not mutate ing.lastCost and updates avg vs last unit '
      'cost and stock balance value matching JS',
      () {
        final fixedNow = DateTime(2026, 11, 4, 12);
        final s = _loadSeededState(fixedNow);
        const today = '2026-11-04';

        final i1Before = s.ingredients.firstWhere((x) => x.id == 'i1');
        expect(i1Before.lastCost, 18500);

        final saved = savePurchase(
          s,
          date: today,
          supplierId: 'sup1',
          note: 'test',
          lines: const <PurchaseLine>[
            PurchaseLine(ingId: 'i1', qty: 10, total: 200000),
          ],
          me: cashier,
          now: fixedNow,
        );
        expect(saved, isTrue);

        // ing.lastCost remains untouched at initial fallback 185
        final i1After = s.ingredients.firstWhere((x) => x.id == 'i1');
        expect(i1After.lastCost, 18500);

        // costMethod == 'avg'
        final ledAvg = computeLedger(s, today: today);
        final rowsAvg = computeStockBalanceRows(s, ledAvg);
        final rowI1Avg = rowsAvg.firstWhere((r) => r.ing.id == 'i1');
        expect(r2(rowI1Avg.qty), 22.5);
        expect(r2(rowI1Avg.unitCost / 100), 196.03);
        expect(r2(rowI1Avg.val / 100), 4410.61);

        // costMethod == 'last'
        s.shop = s.shop.copyWith(costMethod: 'last');
        final ledLast = computeLedger(s, today: today);
        final rowsLast = computeStockBalanceRows(s, ledLast);
        final rowI1Last = rowsLast.firstWhere((r) => r.ing.id == 'i1');
        expect(r2(rowI1Last.qty), 22.5);
        expect(r2(rowI1Last.unitCost / 100), 196.23);
        expect(r2(rowI1Last.val / 100), 4415.11);
      },
    );
  });

  group('saveExpenses & deleteExpense JS parity (Rule 4)', () {
    test('saveExpenses adds daily expense and reduces closed day netProfit '
        'matching JS', () {
      final fixedNow = DateTime(2026, 11, 4, 12);
      final s = _loadSeededState(fixedNow);
      const targetDate = '2026-11-03';

      final before = computeLedger(s, today: '2026-11-04').byDate[targetDate]!;
      expect(before.expenses, 10000);
      expect(r2(before.netProfit! / 100), 15298.97);

      final ok = saveExpenses(
        s,
        date: targetDate,
        lines: const <ExpenseDraftLine>[
          ExpenseDraftLine(typeId: 'et1', amount: 35000, note: 'น้ำแข็งเพิ่ม'),
        ],
        me: cashier,
        now: fixedNow,
      );
      expect(ok, isTrue);

      final after = computeLedger(s, today: '2026-11-04').byDate[targetDate]!;
      expect(after.expenses, 45000);
      expect(r2(after.netProfit! / 100), 14948.97);
    });
  });
}
