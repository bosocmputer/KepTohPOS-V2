import 'package:app/domain/ledger.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/roles.dart';

export 'package:app/domain/reports_ops.dart';

/// Ingredient cost share entry for `DashboardView` (`ingShare` in
/// `prototype/index.html:1543`).
class IngredientCostShareRow {
  const new({
    required this.ing,
    required this.cost,
    required this.sharePct,
    required this.barRatio,
  });

  final IngredientItem ing;
  final double cost;
  final double sharePct;
  final double barRatio;
}

/// Addon sales summary entry for `DashboardView` (`addonAgg` in
/// `prototype/index.html:1544-1545`).
class AddonSalesSummaryRow {
  const new({
    required this.name,
    required this.qty,
    required this.rev,
    required this.cost,
  });

  final String name;
  final int qty;
  final double rev;
  final double cost;

  double get grossProfit => rev - cost;
}

/// Immutable computed summary for `/dashboard` (`DashboardView` in
/// `prototype/index.html:1530-1582`).
class DashboardSummary {
  const new({
    required this.range,
    required this.todayKey,
    required this.showNetProfit,
    required this.days,
    required this.closedDays,
    required this.net,
    required this.bills,
    required this.heads,
    required this.avgHeadsPerDay,
    required this.ingCost,
    required this.addonCost,
    required this.profit,
    required this.netProfit,
    required this.spend,
    required this.closedHeadsW,
    required this.costPerHead,
    required this.closedBuffetNet,
    required this.foodPct,
    required this.todayOpen,
    required this.lastClosedDay,
    required this.bestDay,
    required this.worstDay,
    required this.ingredientShares,
    required this.addonSales,
  });

  final String range;
  final String todayKey;
  final bool showNetProfit;
  final List<LedgerDaySummary> days;
  final List<LedgerDaySummary> closedDays;
  final double net;
  final int bills;
  final int heads;
  final double avgHeadsPerDay;
  final double ingCost;
  final double addonCost;
  final double profit;
  final double netProfit;
  final double spend;
  final double closedHeadsW;
  final double? costPerHead;
  final double closedBuffetNet;
  final double? foodPct;
  final bool todayOpen;
  final LedgerDaySummary? lastClosedDay;
  final LedgerDaySummary? bestDay;
  final LedgerDaySummary? worstDay;
  final List<IngredientCostShareRow> ingredientShares;
  final List<AddonSalesSummaryRow> addonSales;

  String get field => showNetProfit ? 'netProfit' : 'profit';
  String get fieldName => showNetProfit ? 'กำไรสุทธิ' : 'กำไรขั้นต้น';

  /// Returns `netProfit` or `profit` for [d] depending on [showNetProfit].
  double? dayMetric(LedgerDaySummary d) =>
      showNetProfit ? d.netProfit : d.profit;
}

/// Computes `DashboardSummary` for [range] (`'today'`, `'7'`, `'month'`,
/// `'30'`) matching `DashboardView` in `prototype/index.html:1530-1582`.
DashboardSummary computeDashboardSummary(
  PosState s,
  LedgerResult ledger, {
  String range = '30',
  String? today,
}) {
  final tk =
      today ??
      (ledger.days.isNotEmpty ? ledger.days.last.date : dkey(DateTime.now()));
  final showNet = s.shop.showNetProfit;
  final all = ledger.days;
  final List<LedgerDaySummary> days;
  if (range == 'today') {
    days = all.where((d) => d.date == tk).toList();
  } else if (range == 'month') {
    final ym = tk.substring(0, 7);
    days = all.where((d) => d.date.startsWith(ym)).toList();
  } else {
    final count = int.tryParse(range) ?? 30;
    days = all.length > count ? all.sublist(all.length - count) : all.toList();
  }

  final closed = days.where((d) => d.closed).toList();
  final net = days.fold<double>(0, (a, d) => a + d.net);
  final bills = days.fold<int>(0, (a, d) => a + d.bills);
  final heads = days.fold<int>(0, (a, d) => a + d.heads);
  final ingCost = closed.fold<double>(0, (a, d) => a + (d.ingCost ?? 0));
  final addonCost = closed.fold<double>(0, (a, d) => a + d.addonCost);
  final profit = closed.fold<double>(0, (a, d) => a + (d.profit ?? 0));
  final netProfit = closed.fold<double>(0, (a, d) => a + (d.netProfit ?? 0));
  final spend = closed.fold<double>(0, (a, d) => a + d.expenses + d.fixed);
  final cHeadsW = closed.fold<double>(0, (a, d) => a + d.headsW);
  final cBuffet = closed.fold<double>(0, (a, d) => a + d.buffetNet);
  final todayOpen = days.any((d) => d.isToday && !d.closed);
  final lastClosed = all.reversed.where((d) => d.closed).firstOrNull;

  final rawShares = <({IngredientItem ing, double cost})>[];
  for (final ing in s.ingredients) {
    var v = 0.0;
    for (final d in closed) {
      for (final r in d.rows) {
        if (r.ing.id == ing.id) {
          v += r.cost ?? 0;
          break;
        }
      }
    }
    if (v > 0) {
      rawShares.add((ing: ing, cost: v));
    }
  }
  rawShares.sort((a, b) => b.cost.compareTo(a.cost));
  final topRaw = rawShares.take(8).toList();
  final maxIngCost = topRaw.isNotEmpty ? topRaw.first.cost : 0.0;
  final ingredientShares = [
    for (final x in topRaw)
      IngredientCostShareRow(
        ing: x.ing,
        cost: x.cost,
        sharePct: ingCost > 0 ? x.cost / ingCost * 100 : 0,
        barRatio: maxIngCost > 0 ? x.cost / maxIngCost : 0,
      ),
  ];

  final dateSet = {for (final d in days) d.date};
  final addonAgg = <String, ({int q, double rev, double cost})>{};
  for (final b in s.sales) {
    if (!b.voided && dateSet.contains(b.date)) {
      for (final l in b.lines) {
        if (l.type == 'addon') {
          final prev = addonAgg[l.name] ?? (q: 0, rev: 0.0, cost: 0.0);
          addonAgg[l.name] = (
            q: prev.q + l.qty,
            rev: prev.rev + l.qty * l.price,
            cost: prev.cost + l.qty * (l.cost ?? 0),
          );
        }
      }
    }
  }
  final addonSales = [
    for (final e in addonAgg.entries)
      AddonSalesSummaryRow(
        name: e.key,
        qty: e.value.q,
        rev: e.value.rev,
        cost: e.value.cost,
      ),
  ]..sort((a, b) => b.rev.compareTo(a.rev));

  double valOf(LedgerDaySummary d) => (showNet ? d.netProfit : d.profit) ?? 0.0;

  LedgerDaySummary? bestDay;
  LedgerDaySummary? worstDay;
  if (closed.isNotEmpty) {
    bestDay = closed.reduce((a, b) => valOf(b) > valOf(a) ? b : a);
    worstDay = closed.reduce((a, b) => valOf(b) < valOf(a) ? b : a);
  }

  return DashboardSummary(
    range: range,
    todayKey: tk,
    showNetProfit: showNet,
    days: days,
    closedDays: closed,
    net: net,
    bills: bills,
    heads: heads,
    avgHeadsPerDay: days.isNotEmpty ? heads / days.length : 0,
    ingCost: ingCost,
    addonCost: addonCost,
    profit: profit,
    netProfit: netProfit,
    spend: spend,
    closedHeadsW: cHeadsW,
    costPerHead: cHeadsW > 0 ? ingCost / cHeadsW : null,
    closedBuffetNet: cBuffet,
    foodPct: cBuffet > 0 ? ingCost / cBuffet * 100 : null,
    todayOpen: todayOpen,
    lastClosedDay: lastClosed,
    bestDay: bestDay,
    worstDay: worstDay,
    ingredientShares: ingredientShares,
    addonSales: addonSales,
  );
}
