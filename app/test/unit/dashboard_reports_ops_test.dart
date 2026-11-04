// Expected numbers in this test file were generated directly by executing the
// JS reference implementation in `prototype/index.html` (lines 450-763,
// `DashboardView` lines 1530-1582, `ReportsView` lines 1585-1615) +
// `prototype/data/mock-data.js` via Node.js (`node`) with fixed clock
// `new Date(2026, 10, 4, 12, 0, 0, 0)` and `rng(20261103)`.
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
  final fixedNow = DateTime(2026, 11, 4, 12);

  group('computeDashboardSummary JS parity across ranges', () {
    test('30-day summary matches JS DashboardView and 2026-11-03 gross 16,935.64 / '
        'net 15,298.97', () {
      final s = _loadSeededState(fixedNow);
      final ledger = computeLedger(s, today: '2026-11-04');
      final sum30 = computeDashboardSummary(s, ledger, today: '2026-11-04');

      expect(sum30.range, '30');
      expect(sum30.days.length, 30);
      expect(sum30.closedDays.length, 29);
      expect(sum30.days.first.date, '2026-10-06');
      expect(sum30.days.last.date, '2026-11-04');
      expect(sum30.todayOpen, isTrue);

      // Last closed day (2026-11-03) exact parity with existing ledger test
      final last = sum30.lastClosedDay!;
      expect(last.date, '2026-11-03');
      expect(r2(last.profit!), 16935.64);
      expect(r2(last.netProfit!), 15298.97);

      // Period totals
      expect(r2(sum30.net), 845443);
      expect(sum30.bills, 859);
      expect(sum30.heads, 3337);
      expect(r2(sum30.avgHeadsPerDay), 111.23);
      expect(r2(sum30.ingCost), 240677.75);
      expect(r2(sum30.addonCost), 87696);
      expect(r2(sum30.profit), 508239.25);
      expect(r2(sum30.netProfit), 456995.91);
      expect(r2(sum30.spend), 51243.33);
      expect(r2(sum30.closedHeadsW), 3194.5);
      expect(r2(sum30.costPerHead!), 75.34);
      expect(r2(sum30.closedBuffetNet), 689438);
      expect(r2(sum30.foodPct!), 34.91);

      // Best & worst day under showNetProfit = true
      expect(sum30.bestDay!.date, '2026-10-17');
      expect(r2(sum30.dayMetric(sum30.bestDay!)!), 25619.06);
      expect(sum30.worstDay!.date, '2026-10-14');
      expect(r2(sum30.dayMetric(sum30.worstDay!)!), 10411.46);

      // Top ingredient cost shares (sorted descending, max 8)
      expect(sum30.ingredientShares.length, 8);
      expect(sum30.ingredientShares[0].ing.id, 'i1');
      expect(r2(sum30.ingredientShares[0].cost), 65475.92);
      expect(sum30.ingredientShares[0].sharePct.round(), 27);
      expect(sum30.ingredientShares[1].ing.id, 'i3');
      expect(r2(sum30.ingredientShares[1].cost), 34378.83);
      expect(sum30.ingredientShares[2].ing.id, 'i2');
      expect(r2(sum30.ingredientShares[2].cost), 33138.74);

      // Top addon sales (sorted descending by revenue)
      expect(sum30.addonSales.first.name, 'เบียร์สิงห์ ขวดใหญ่');
      expect(sum30.addonSales.first.qty, 431);
      expect(r2(sum30.addonSales.first.rev), 38790);
      expect(r2(sum30.addonSales.first.grossProfit), 11637);
    });

    test('today, 7-day, month, and showNetProfit=false summaries match JS', () {
      final s = _loadSeededState(fixedNow);
      final ledger = computeLedger(s, today: '2026-11-04');

      final sumToday = computeDashboardSummary(
        s,
        ledger,
        range: 'today',
        today: '2026-11-04',
      );
      expect(sumToday.days.length, 1);
      expect(sumToday.closedDays, isEmpty);
      expect(sumToday.todayOpen, isTrue);
      expect(r2(sumToday.net), 8830);
      expect(sumToday.bills, 9);
      expect(sumToday.heads, 35);
      expect(sumToday.costPerHead, isNull);
      expect(sumToday.foodPct, isNull);
      expect(sumToday.ingredientShares, isEmpty);
      expect(sumToday.addonSales.first.name, 'เบียร์ลีโอ ขวดใหญ่');
      expect(sumToday.addonSales.first.qty, 9);

      final sum7 = computeDashboardSummary(
        s,
        ledger,
        range: '7',
        today: '2026-11-04',
      );
      expect(sum7.days.length, 7);
      expect(sum7.closedDays.length, 6);
      expect(r2(sum7.net), 189100);
      expect(r2(sum7.ingCost), 51575.06);
      expect(r2(sum7.profit), 109272.94);
      expect(r2(sum7.netProfit), 98612.94);
      expect(r2(sum7.costPerHead!), 74.85);
      expect(r2(sum7.foodPct!), 34.89);

      final sumMonth = computeDashboardSummary(
        s,
        ledger,
        range: 'month',
        today: '2026-11-04',
      );
      expect(sumMonth.days.length, 4);
      expect(sumMonth.closedDays.length, 3);
      expect(r2(sumMonth.net), 90379);
      expect(r2(sumMonth.ingCost), 23014.66);
      expect(r2(sumMonth.profit), 49294.34);
      expect(r2(sumMonth.netProfit), 43964.34);
      expect(r2(sumMonth.costPerHead!), 73.53);
      expect(r2(sumMonth.foodPct!), 34.77);

      // showNetProfit = false uses gross profit for best/worst and dayMetric
      s.shop = s.shop.copyWith(showNetProfit: false);
      final sumGross = computeDashboardSummary(s, ledger, today: '2026-11-04');
      expect(sumGross.showNetProfit, isFalse);
      expect(sumGross.field, 'profit');
      expect(sumGross.fieldName, 'กำไรขั้นต้น');
      expect(sumGross.bestDay!.date, '2026-10-17');
      expect(r2(sumGross.dayMetric(sumGross.bestDay!)!), 27675.73);
      expect(sumGross.worstDay!.date, '2026-10-06');
      expect(r2(sumGross.dayMetric(sumGross.worstDay!)!), 12374.87);
    });
  });

  group('computeMonthlyReport JS parity across months', () {
    test('2026-11 and 2026-10 monthly reports match JS ReportsView', () {
      final s = _loadSeededState(fixedNow);
      final ledger = computeLedger(s, today: '2026-11-04');

      final repNov = computeMonthlyReport(s, ledger);
      expect(repNov.availableMonths, equals(['2026-11', '2026-10']));
      expect(repNov.selectedMonth, '2026-11');
      expect(repNov.days.length, 4);
      expect(repNov.closedDays.length, 3);
      expect(repNov.reversedDays.first.date, '2026-11-04');
      expect(repNov.reversedDays.last.date, '2026-11-01');
      expect(repNov.totalBills, 95);
      expect(repNov.totalHeads, 356);
      expect(r2(repNov.totalBuffetNet), 73064);
      expect(r2(repNov.totalAddonNet), 17315);
      expect(r2(repNov.totalNet), 90379);
      expect(r2(repNov.totalPurchases), 30717);
      expect(r2(repNov.closedIngCost), 23014.66);
      expect(r2(repNov.closedAddonCost), 9240);
      expect(r2(repNov.closedProfit), 49294.34);
      expect(r2(repNov.closedSpend), 5330);
      expect(r2(repNov.closedNetProfit), 43964.34);
      expect(r2(repNov.closedCostPerHead!), 73.53);
      expect(r2(repNov.closedFoodPct!), 34.77);

      final repOct = computeMonthlyReport(s, ledger, month: '2026-10');
      expect(repOct.selectedMonth, '2026-10');
      expect(repOct.days.length, 27);
      expect(repOct.closedDays.length, 27);
      expect(repOct.totalBills, 787);
      expect(repOct.totalHeads, 3073);
      expect(r2(repOct.totalBuffetNet), 640927);
      expect(r2(repOct.totalAddonNet), 136700);
      expect(r2(repOct.totalNet), 777627);
      expect(r2(repOct.totalPurchases), 222911);
      expect(r2(repOct.closedIngCost), 224417.65);
      expect(r2(repOct.closedAddonCost), 81460);
      expect(r2(repOct.closedProfit), 471749.35);
      expect(r2(repOct.closedSpend), 47970);
      expect(r2(repOct.closedNetProfit), 423779.35);
      expect(r2(repOct.closedCostPerHead!), 75.56);
      expect(r2(repOct.closedFoodPct!), 35.01);
    });
  });
}
