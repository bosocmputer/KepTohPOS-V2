import 'dart:math' as math;

import 'package:app/domain/models.dart';
import 'package:app/domain/order_calc.dart';
import 'package:app/domain/roles.dart';

int _idCounter = 0;

String _genUid(String prefix, DateTime now) {
  _idCounter = (_idCounter + 1) & 0xFFFFF;
  final ts = now.millisecondsSinceEpoch.toRadixString(36);
  final tail = ts.length > 4 ? ts.substring(ts.length - 4) : ts;
  return '$prefix$tail${_idCounter.toRadixString(36).padLeft(4, '0')}';
}

/// Finds the currently open shift (`openShiftOf` in `prototype/index.html`).
ShiftRecord? openShiftOf(PosState s) {
  for (final sh in s.shifts) {
    if (sh.closedAt == null) return sh;
  }
  return null;
}

/// Deducts (or restores when negative) addon stock (`takeStock` in JS).
void takeStock(PosState st, Map<String, int> ad) {
  for (final entry in ad.entries) {
    final qty = entry.value;
    if (qty == 0) continue;
    for (final x in st.addons) {
      if (x.id == entry.key) {
        x.stock = math.max(0, x.stock - qty);
        break;
      }
    }
  }
}

/// Builds a [TableRound] from [cart] (`newRound` in `prototype/index.html`).
TableRound newRound(
  TableTotals cart,
  StaffMember me, {
  DateTime? now,
  String? id,
}) {
  final current = now ?? DateTime.now();
  final filteredAd = <String, int>{
    for (final e in cart.ad.entries)
      if (e.value > 0) e.key: e.value,
  };
  return TableRound(
    id: id ?? _genUid('r', current),
    at: current.toUtc().toIso8601String(),
    staffId: me.id,
    a: cart.a,
    c: cart.c,
    f: cart.f,
    ad: filteredAd,
  );
}

/// Opens a table or adds head counts to an already-open table (`openOrAdd`).
OpenTableState openOrAdd(
  PosState st,
  DiningTable table,
  TableTotals cart,
  String timing,
  String pkgId,
  String? notes, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final existing = st.openTables[table.id];
  final o =
      existing ??
      (st.openTables[table.id] = OpenTableState(
        openedAt: current.toUtc().toIso8601String(),
        packageId: pkgId,
        timing: timing,
        notes: notes ?? '',
      ));
  o.heads.a += cart.a;
  o.heads.c += cart.c;
  o.heads.f += cart.f;
  return o;
}

/// Sends an order round in eat-before-paying mode (`sendRound`).
void sendRound(
  PosState st,
  DiningTable table,
  TableTotals cart,
  StaffMember me,
  String timing,
  String pkgId,
  String? notes, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final o = openOrAdd(st, table, cart, timing, pkgId, notes, now: current);
  o.rounds.add(newRound(cart, me, now: current));
  takeStock(st, cart.ad);
}

/// Creates and records a settled [BillRecord] (`makeBill` in `index.html`).
BillRecord makeBill(
  PosState s, {
  required String id,
  required String at,
  required String tableId,
  required String staffId,
  required String packageId,
  required CalculatedOrder order,
  required PaymentMethod method,
  required double received,
  String? shiftId,
}) {
  final date = dkey(DateTime.parse(at).toLocal());
  final nextSeq = (s.seq[date] ?? 0) + 1;
  s.seq[date] = nextSeq;

  DiningTable? table;
  for (final t in s.tables) {
    if (t.id == tableId) {
      table = t;
      break;
    }
  }
  StaffMember? staff;
  for (final x in s.staff) {
    if (x.id == staffId) {
      staff = x;
      break;
    }
  }

  final isCash = method.type == 'cash';
  final shortDate = date.substring(2).replaceAll('-', '');
  final bill = BillRecord(
    id: id,
    no: '$shortDate-${padInt(nextSeq, 3)}',
    date: date,
    at: at,
    tableId: tableId,
    tableName: table != null ? table.name : '-',
    staffId: staffId,
    staffName: staff != null ? staff.name : '-',
    shiftId: shiftId,
    packageId: packageId,
    lines: order.lines,
    subtotal: order.subtotal,
    service: order.service,
    vat: order.vat,
    rounding: order.rounding,
    total: order.total,
    heads: order.heads.copy(),
    methodId: method.id,
    methodName: method.name,
    methodType: method.type,
    received: isCash ? received : order.total,
    change: isCash ? r2(received - order.total) : 0,
  );
  s.sales.add(bill);
  return bill;
}

/// Settles an order for both pay-before-eating and eat-before-paying modes
/// (`settle` in `prototype/index.html`).
CalculatedOrder settle(
  PosState st,
  DiningTable table,
  TableTotals cart,
  StaffMember me, {
  required String timing,
  required String pkgId,
  required PaymentMethod method,
  required double received,
  required String billId,
  String? notes,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final o = openOrAdd(st, table, cart, timing, pkgId, notes, now: current);
  PackageItem? pkg;
  for (final p in st.packages) {
    if (p.id == o.packageId) {
      pkg = p;
      break;
    }
  }

  final CalculatedOrder order;
  if (o.timing == 'after') {
    if (!totalsEmpty(cart)) {
      o.rounds.add(newRound(cart, me, now: current));
      takeStock(st, cart.ad);
    }
    order = orderOf(st, pkg, tableTotals(o));
  } else {
    order = orderOf(st, pkg, cart);
    takeStock(st, cart.ad);
  }

  final activeShift = openShiftOf(st);
  makeBill(
    st,
    id: billId,
    at: current.toUtc().toIso8601String(),
    tableId: table.id,
    staffId: me.id,
    shiftId: activeShift?.id,
    packageId: o.packageId,
    order: order,
    method: method,
    received: method.type == 'cash' ? received : order.total,
  );
  o.billIds.add(billId);
  if (o.timing == 'after') {
    o.log.addAll(o.adjusts);
    o
      ..rounds = <TableRound>[]
      ..adjusts = <TableAdjustment>[];
  }
  return order;
}

/// Reduces/removes an already-sent item and restores addon stock (`adjustSent`).
void adjustSent(
  PosState st,
  String tableId,
  String kind,
  String key,
  int qty,
  String reason,
  StaffMember me, {
  DateTime? now,
}) {
  final o = st.openTables[tableId];
  if (o == null) return;
  final t = tableTotals(o);
  final have = kind == 'head' ? t.headOf(key) : (t.ad[key] ?? 0);
  final n = math.min(qty, have);
  if (n <= 0) return;
  final current = now ?? DateTime.now();
  o.adjusts.add(
    TableAdjustment(
      id: _genUid('j', current),
      at: current.toUtc().toIso8601String(),
      by: me.id,
      byName: me.name,
      reason: reason,
      kind: kind,
      key: key,
      qty: -n,
    ),
  );
  if (kind == 'head') {
    o.heads[key] = math.max(0, o.heads[key] - n);
  } else {
    takeStock(st, <String, int>{key: -n});
  }
}
