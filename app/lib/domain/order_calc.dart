import 'dart:math' as math;

import 'package:app/domain/models.dart';

/// Returns [percent] of [satang], rounding half up in integer arithmetic so the
/// result is identical to `numeric` rounding in `private.calc_bill_amounts`.
int _percentOf(int satang, double percent) =>
    (satang * (percent * 100).round() + 5000) ~/ 10000;

/// Calculates order lines, subtotal, service charge, VAT, rounding, and total
/// in satang (`calcOrder` in `prototype/index.html`).
CalculatedOrder calcOrder(
  ShopConfig shop,
  PackageItem? pkg,
  int a,
  int c,
  int f,
  List<AddonLineInput> addonLines, {
  String? roundingOverride,
}) {
  final lines = <OrderLineItem>[];
  if (pkg != null && a > 0) {
    lines.add(
      OrderLineItem(
        type: 'buffet',
        name: '${pkg.name} · ผู้ใหญ่',
        qty: a,
        price: pkg.adultPrice,
      ),
    );
  }
  if (pkg != null && c > 0) {
    lines.add(
      OrderLineItem(
        type: 'buffet',
        name: '${pkg.name} · เด็ก',
        qty: c,
        price: pkg.childPrice,
      ),
    );
  }
  if (pkg != null && f > 0) {
    lines.add(
      const OrderLineItem(
        type: 'buffet',
        name: 'เด็กเล็ก (ทานฟรี)',
        qty: 0,
        price: 0,
      ),
    );
    lines[lines.length - 1] = OrderLineItem(
      type: 'buffet',
      name: 'เด็กเล็ก (ทานฟรี)',
      qty: f,
      price: 0,
    );
  }
  for (final l in addonLines) {
    if (l.qty > 0) {
      lines.add(
        OrderLineItem(
          type: 'addon',
          id: l.addon.id,
          name: l.addon.name,
          qty: l.qty,
          price: l.addon.price,
          cost: l.addon.cost,
        ),
      );
    }
  }
  final subtotal = lines.fold<int>(0, (sum, l) => sum + l.qty * l.price);
  final service = _percentOf(subtotal, shop.servicePct);
  final base = subtotal + service;
  final vatRate = shop.vatRate > 0 ? shop.vatRate : 0.0;
  var vat = 0;
  var total = base;
  var rounding = 0;
  if (shop.vatMode == 'excluded' && vatRate > 0) {
    vat = _percentOf(base, vatRate);
    total = base + vat;
  }
  final effectiveRounding = roundingOverride ?? shop.rounding;
  final roundsDown = effectiveRounding == 'down' && total % 100 != 0;
  if (roundsDown) {
    rounding = -(total % 100);
    total += rounding;
  }
  // Rounding is a discount: VAT is taken from the rounded total.
  if ((shop.vatMode == 'included' ||
          (roundsDown && shop.vatMode == 'excluded')) &&
      vatRate > 0) {
    final basisPoints = (vatRate * 100).round();
    final divisor = 10000 + basisPoints;
    vat = (2 * total * basisPoints + divisor) ~/ (2 * divisor);
  }
  return CalculatedOrder(
    lines: lines,
    subtotal: subtotal,
    service: service,
    vat: vat,
    rounding: rounding,
    total: total,
    heads: HeadsCount(a: a, c: c, f: f),
  );
}

/// Aggregates sent rounds and adjustments on an open table (`tableTotals`).
TableTotals tableTotals(OpenTableState o) {
  var a = 0;
  var c = 0;
  var f = 0;
  final ad = <String, int>{};
  for (final r in o.rounds) {
    a += r.a;
    c += r.c;
    f += r.f;
    for (final entry in r.ad.entries) {
      ad[entry.key] = (ad[entry.key] ?? 0) + entry.value;
    }
  }
  for (final j in o.adjusts) {
    if (j.kind == 'head') {
      switch (j.key) {
        case 'a':
          a += j.qty;
        case 'c':
          c += j.qty;
        case 'f':
          f += j.qty;
      }
    } else {
      ad[j.key] = (ad[j.key] ?? 0) + j.qty;
    }
  }
  a = math.max(0, a);
  c = math.max(0, c);
  f = math.max(0, f);
  for (final k in ad.keys.toList()) {
    ad[k] = math.max(0, ad[k] ?? 0);
  }
  return TableTotals(a: a, c: c, f: f, ad: ad);
}

/// Merges two [TableTotals] instances (`mergeTotals`).
TableTotals mergeTotals(TableTotals x, TableTotals y) {
  final keys = <String>{...x.ad.keys, ...y.ad.keys};
  final mergedAd = <String, int>{
    for (final k in keys) k: (x.ad[k] ?? 0) + (y.ad[k] ?? 0),
  };
  return TableTotals(a: x.a + y.a, c: x.c + y.c, f: x.f + y.f, ad: mergedAd);
}

/// Returns true when [t] has zero heads and zero addons (`totalsEmpty`).
bool totalsEmpty(TableTotals t) =>
    (t.a + t.c + t.f) == 0 && !t.ad.values.any((q) => q > 0);

/// Calculates an order for [t] against state [s] (`orderOf`).
CalculatedOrder orderOf(
  PosState s,
  PackageItem? pkg,
  TableTotals t, {
  String? roundingOverride,
}) => calcOrder(
  s.shop,
  pkg,
  t.a,
  t.c,
  t.f,
  s.addons.map((x) => AddonLineInput(addon: x, qty: t.ad[x.id] ?? 0)).toList(),
  roundingOverride: roundingOverride,
);

/// Returns the unpaid balance for eat-before-paying table [o] (`tableDue`).
int tableDue(PosState s, OpenTableState o) {
  if (o.timing != 'after') return 0;
  final t = tableTotals(o);
  if (totalsEmpty(t)) return 0;
  PackageItem? pkg;
  for (final p in s.packages) {
    if (p.id == o.packageId) {
      pkg = p;
      break;
    }
  }
  return orderOf(s, pkg, t).total;
}

/// Computes elapsed time and remaining/overdue status for [o] (`tableTimer`).
TableTimerStatus tableTimer(PosState s, OpenTableState o, {DateTime? now}) {
  final current = now ?? DateTime.now();
  PackageItem? pkg;
  for (final p in s.packages) {
    if (p.id == o.packageId) {
      pkg = p;
      break;
    }
  }
  final openedMs = DateTime.parse(o.openedAt).millisecondsSinceEpoch;
  final mins = ((current.millisecondsSinceEpoch - openedMs) / 60000).floor();
  final limit = (s.shop.useTimer && pkg != null && pkg.timeLimit > 0)
      ? pkg.timeLimit
      : 0;
  final late = limit > 0 && mins > limit;
  final String text;
  if (limit > 0) {
    text = late ? 'เกินเวลา ${mins - limit} น.' : 'เหลือ ${limit - mins} น.';
  } else {
    text = 'นั่งมา $mins น.';
  }
  return TableTimerStatus(mins: mins, limit: limit, late: late, text: text);
}

/// Returns the local deadline (`openedAt + pkg.timeLimit`) for [o] when
/// `s.shop.useTimer && pkg.timeLimit > 0`, or `null` if unlimited/disabled.
DateTime? eatUntilOf(PosState s, OpenTableState o) {
  if (!s.shop.useTimer) return null;
  final pkg = s.packages.where((p) => p.id == o.packageId).firstOrNull;
  if (pkg == null || pkg.timeLimit <= 0) return null;
  return DateTime.parse(o.openedAt)
      .toLocal()
      .add(Duration(minutes: pkg.timeLimit));
}

/// Computes `(eatUntilIso, timeLimitMin)` for a bill or POS slip on [tableId]
/// so customers added later share the open table's `openedAt` deadline.
(String? eatUntil, int timeLimitMin) billTimerSnapshot(
  PosState s,
  String tableId,
  String packageId,
  String fallbackAt,
) {
  if (!s.shop.useTimer) return (null, 0);
  final pkg = s.packages.where((p) => p.id == packageId).firstOrNull;
  if (pkg == null || pkg.timeLimit <= 0) return (null, 0);
  final baseIso = s.openTables[tableId]?.openedAt ?? fallbackAt;
  final until = DateTime.parse(baseIso)
      .toUtc()
      .add(Duration(minutes: pkg.timeLimit));
  return (until.toIso8601String(), pkg.timeLimit);
}

/// Formats `timeLimitMin` (e.g. `120` -> `'2 ชม.'`, `90` -> `'1 ชม. 30 นาที'`).
String formatTimeLimitLabel(int mins) {
  if (mins <= 0) return 'ไม่จำกัดเวลา';
  final h = mins ~/ 60;
  final m = mins % 60;
  if (h > 0 && m > 0) return '$h ชม. $m นาที';
  if (h > 0) return '$h ชม.';
  return '$m นาที';
}

/// Lists sent lines with positive quantity (`sentLines` in `index.html`).
List<SentLineItem> sentLines(PosState s, PackageItem? pkg, TableTotals t) {
  final result = <SentLineItem>[];
  if (t.a > 0) {
    result.add(
      SentLineItem(
        kind: 'head',
        key: 'a',
        name: 'ผู้ใหญ่',
        qty: t.a,
        price: pkg?.adultPrice ?? 0,
      ),
    );
  }
  if (t.c > 0) {
    result.add(
      SentLineItem(
        kind: 'head',
        key: 'c',
        name: 'เด็ก',
        qty: t.c,
        price: pkg?.childPrice ?? 0,
      ),
    );
  }
  if (t.f > 0) {
    result.add(
      SentLineItem(
        kind: 'head',
        key: 'f',
        name: 'เด็กเล็ก (ทานฟรี)',
        qty: t.f,
        price: 0,
      ),
    );
  }
  for (final x in s.addons) {
    final qty = t.ad[x.id] ?? 0;
    if (qty > 0) {
      result.add(
        SentLineItem(
          kind: 'addon',
          key: x.id,
          name: x.name,
          qty: qty,
          price: x.price,
        ),
      );
    }
  }
  return result;
}
