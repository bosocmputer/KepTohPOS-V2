import 'package:app/domain/ledger.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/roles.dart';

/// Immutable computed summary for `/reports` (`ReportsView` in
/// `prototype/index.html:1585-1615`).
class MonthlyReportSummary {
  const new({
    required this.availableMonths,
    required this.selectedMonth,
    required this.showNetProfit,
    required this.days,
    required this.reversedDays,
    required this.closedDays,
    required this.totalBills,
    required this.totalHeads,
    required this.totalBuffetNet,
    required this.totalAddonNet,
    required this.totalNet,
    required this.totalPurchases,
    required this.closedIngCost,
    required this.closedAddonCost,
    required this.closedProfit,
    required this.closedSpend,
    required this.closedNetProfit,
    required this.closedHeadsW,
    required this.closedBuffetNet,
    required this.closedCostPerHead,
    required this.closedFoodPct,
  });

  final List<String> availableMonths;
  final String selectedMonth;
  final bool showNetProfit;
  final List<LedgerDaySummary> days;
  final List<LedgerDaySummary> reversedDays;
  final List<LedgerDaySummary> closedDays;
  final int totalBills;
  final int totalHeads;
  final double totalBuffetNet;
  final double totalAddonNet;
  final double totalNet;
  final double totalPurchases;
  final double closedIngCost;
  final double closedAddonCost;
  final double closedProfit;
  final double closedSpend;
  final double closedNetProfit;
  final double closedHeadsW;
  final double closedBuffetNet;
  final double? closedCostPerHead;
  final double? closedFoodPct;
}

/// Computes `MonthlyReportSummary` for [month] (`YYYY-MM`), defaulting to the
/// latest month in [ledger], matching `ReportsView` in `prototype/index.html`.
MonthlyReportSummary computeMonthlyReport(
  PosState s,
  LedgerResult ledger, {
  String? month,
}) {
  final monthSet = <String>{
    for (final d in ledger.days) d.date.substring(0, 7),
  };
  final months = monthSet.toList().reversed.toList();
  final selected = (month != null && months.contains(month))
      ? month
      : (months.isNotEmpty
            ? months.first
            : dkey(DateTime.now()).substring(0, 7));
  final days = ledger.days.where((d) => d.date.startsWith(selected)).toList();
  final closed = days.where((d) => d.closed).toList();

  final totalBills = days.fold<int>(0, (a, d) => a + d.bills);
  final totalHeads = days.fold<int>(0, (a, d) => a + d.heads);
  final totalBuffetNet = days.fold<double>(0, (a, d) => a + d.buffetNet);
  final totalAddonNet = days.fold<double>(0, (a, d) => a + d.addonNet);
  final totalNet = days.fold<double>(0, (a, d) => a + d.net);
  final totalPurchases = days.fold<double>(0, (a, d) => a + d.purchases);

  final closedIngCost = closed.fold<double>(0, (a, d) => a + (d.ingCost ?? 0));
  final closedAddonCost = closed.fold<double>(0, (a, d) => a + d.addonCost);
  final closedProfit = closed.fold<double>(0, (a, d) => a + (d.profit ?? 0));
  final closedSpend = closed.fold<double>(
    0,
    (a, d) => a + d.expenses + d.fixed,
  );
  final closedNetProfit = closed.fold<double>(
    0,
    (a, d) => a + (d.netProfit ?? 0),
  );
  final closedHeadsW = closed.fold<double>(0, (a, d) => a + d.headsW);
  final closedBuffetNet = closed.fold<double>(0, (a, d) => a + d.buffetNet);

  return MonthlyReportSummary(
    availableMonths: months,
    selectedMonth: selected,
    showNetProfit: s.shop.showNetProfit,
    days: days,
    reversedDays: days.reversed.toList(),
    closedDays: closed,
    totalBills: totalBills,
    totalHeads: totalHeads,
    totalBuffetNet: totalBuffetNet,
    totalAddonNet: totalAddonNet,
    totalNet: totalNet,
    totalPurchases: totalPurchases,
    closedIngCost: closedIngCost,
    closedAddonCost: closedAddonCost,
    closedProfit: closedProfit,
    closedSpend: closedSpend,
    closedNetProfit: closedNetProfit,
    closedHeadsW: closedHeadsW,
    closedBuffetNet: closedBuffetNet,
    closedCostPerHead: closedHeadsW > 0 ? closedIngCost / closedHeadsW : null,
    closedFoodPct: closedBuffetNet > 0
        ? closedIngCost / closedBuffetNet * 100
        : null,
  );
}
