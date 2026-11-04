import 'package:app/domain/models.dart';

/// Rolling inventory valuation and usage state per ingredient (`current[id]`).
class IngredientLedgerState {
  const new({
    required this.qty,
    required this.avg,
    required this.last,
    required this.rate,
    required this.sinceUsed,
    required this.sinceHeads,
  });

  final double qty;
  final double avg;
  final double last;
  final double? rate;
  final double sinceUsed;
  final double sinceHeads;
}

/// Per-ingredient daily ledger breakdown (`day.rows[i]` in `computeLedger`).
class IngredientDayRow {
  const new({
    required this.ing,
    required this.opening,
    required this.pq,
    required this.pv,
    required this.avail,
    required this.avg,
    required this.unit,
    required this.closing,
    required this.used,
    required this.cost,
    required this.est,
    required this.weekly,
    required this.rate,
  });

  final IngredientItem ing;
  final double opening;
  final double pq;
  final double pv;
  final double avail;
  final double avg;
  final double unit;
  final double? closing;
  final double? used;
  final double? cost;
  final bool est;
  final bool weekly;
  final double? rate;
}

/// Daily revenue, cost, and profit summary (`day` in `computeLedger`).
class LedgerDaySummary {
  const new({
    required this.date,
    required this.closed,
    required this.isToday,
    required this.bills,
    required this.a,
    required this.c,
    required this.f,
    required this.heads,
    required this.headsW,
    required this.gross,
    required this.net,
    required this.buffetNet,
    required this.addonNet,
    required this.addonCost,
    required this.purchases,
    required this.expenses,
    required this.fixed,
    required this.ingCost,
    required this.profit,
    required this.netProfit,
    required this.costPerHead,
    required this.foodPct,
    required this.estItems,
    required this.rows,
  });

  final String date;
  final bool closed;
  final bool isToday;
  final int bills;
  final int a;
  final int c;
  final int f;
  final int heads;
  final double headsW;
  final double gross;
  final double net;
  final double buffetNet;
  final double addonNet;
  final double addonCost;
  final double purchases;
  final double expenses;
  final double fixed;
  final double? ingCost;
  final double? profit;
  final double? netProfit;
  final double? costPerHead;
  final double? foodPct;
  final int estItems;
  final List<IngredientDayRow> rows;
}

/// Full ledger output (`{ days, byDate, current }`).
class LedgerResult {
  const new({required this.days, required this.byDate, required this.current});

  final List<LedgerDaySummary> days;
  final Map<String, LedgerDaySummary> byDate;
  final Map<String, IngredientLedgerState> current;
}
