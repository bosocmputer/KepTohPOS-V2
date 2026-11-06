import 'dart:math' as math;

import 'package:app/domain/models.dart';
import 'package:app/domain/roles.dart';

/// Calculates order lines, subtotal, service charge, VAT, rounding, and total
/// (`calcOrder` in `prototype/index.html`).
CalculatedOrder calcOrder(
  ShopConfig shop,
  PackageItem? pkg,
  int a,
  int c,
  int f,
  List<AddonLineInput> addonLines,
) {
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
  final rawSubtotal = lines.fold<double>(
    0,
    (sum, line) => sum + line.qty * line.price,
  );
  final subtotal = r2(rawSubtotal);
  final service = r2(subtotal * shop.servicePct / 100);
  final base = r2(subtotal + service);
  final vatRate = shop.vatRate > 0 ? shop.vatRate : 0.0;
  var vat = 0.0;
  var total = base;
  var rounding = 0.0;
  if (shop.vatMode == 'excluded' && vatRate > 0) {
    vat = r2(base * (vatRate / 100));
    total = r2(base + vat);
  }
  if (shop.rounding == 'down' && total % 1 != 0) {
    final t = (total + 1e-9).floorToDouble();
    rounding = r2(t - total);
    total = t;
  }
  if (shop.vatMode == 'included' && vatRate > 0) {
    vat = r2(total * vatRate / (100 + vatRate));
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
CalculatedOrder orderOf(PosState s, PackageItem? pkg, TableTotals t) =>
    calcOrder(
      s.shop,
      pkg,
      t.a,
      t.c,
      t.f,
      s.addons
          .map((x) => AddonLineInput(addon: x, qty: t.ad[x.id] ?? 0))
          .toList(),
    );

/// Returns the unpaid balance for eat-before-paying table [o] (`tableDue`).
double tableDue(PosState s, OpenTableState o) {
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
