import 'package:app/domain/models.dart';
import 'package:app/domain/order_calc.dart';
import 'package:app/domain/roles.dart';

/// Aggregated summary of an open table across all sub-bills in the current
/// dining session (`ใบสรุปยอดโต๊ะ`).
class TableSummarySlip {
  const new({
    required this.tableId,
    required this.tableName,
    required this.openedAt,
    required this.eatUntil,
    required this.timeLimitMin,
    required this.timer,
    required this.heads,
    required this.bills,
    required this.mergedLines,
    required this.subtotal,
    required this.service,
    required this.vat,
    required this.rounding,
    required this.total,
    required this.voidedCount,
  });

  final String tableId;
  final String tableName;
  final String openedAt;
  final String? eatUntil;
  final int timeLimitMin;
  final TableTimerStatus timer;
  final HeadsCount heads;
  final List<BillRecord> bills;
  final List<OrderLineItem> mergedLines;
  final double subtotal;
  final double service;
  final double vat;
  final double rounding;
  final double total;
  final int voidedCount;

  int get activeBillCount => bills.length - voidedCount;
}

/// Builds a [TableSummarySlip] for an occupied table (`s.openTables[tableId]`),
/// aggregating all active sub-bills while retaining voided sub-bills from the
/// current session for audit visibility.
TableSummarySlip? buildTableSummarySlip(
  PosState s,
  String tableId, {
  DateTime? now,
}) {
  final o = s.openTables[tableId];
  final tb = s.tables.where((t) => t.id == tableId).firstOrNull;
  if (o == null || tb == null) return null;

  final openedTime = DateTime.parse(o.openedAt);
  final sessionBills = <BillRecord>[];
  for (final b in s.sales) {
    if (b.tableId != tableId) continue;
    final inList = o.billIds.contains(b.id);
    final inSession = !DateTime.parse(b.at).isBefore(openedTime);
    if (inList || inSession) {
      sessionBills.add(b);
    }
  }

  var a = 0;
  var c = 0;
  var f = 0;
  var subtotal = 0.0;
  var service = 0.0;
  var vat = 0.0;
  var rounding = 0.0;
  var total = 0.0;
  var voidedCount = 0;
  final lineMap = <String, OrderLineItem>{};

  for (final b in sessionBills) {
    if (b.voided) {
      voidedCount++;
      continue;
    }
    a += b.heads.a;
    c += b.heads.c;
    f += b.heads.f;
    subtotal = r2(subtotal + b.subtotal);
    service = r2(service + b.service);
    vat = r2(vat + b.vat);
    rounding = r2(rounding + b.rounding);
    total = r2(total + b.total);
    for (final l in b.lines) {
      final key = '${l.type}|${l.id ?? ""}|${l.name}|${l.price}';
      final prev = lineMap[key];
      lineMap[key] = prev == null
          ? OrderLineItem(
              type: l.type,
              id: l.id,
              name: l.name,
              qty: l.qty,
              price: l.price,
              cost: l.cost,
            )
          : OrderLineItem(
              type: prev.type,
              id: prev.id,
              name: prev.name,
              qty: prev.qty + l.qty,
              price: prev.price,
              cost: prev.cost,
            );
    }
  }

  final (eatUntil, limitMin) = billTimerSnapshot(
    s,
    tb.id,
    o.packageId,
    o.openedAt,
  );
  return TableSummarySlip(
    tableId: tb.id,
    tableName: tb.name,
    openedAt: o.openedAt,
    eatUntil: eatUntil,
    timeLimitMin: limitMin,
    timer: tableTimer(s, o, now: now),
    heads: HeadsCount(a: a, c: c, f: f),
    bills: sessionBills,
    mergedLines: lineMap.values.toList(),
    subtotal: subtotal,
    service: service,
    vat: vat,
    rounding: rounding,
    total: total,
    voidedCount: voidedCount,
  );
}
