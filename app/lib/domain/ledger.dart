import 'dart:math' as math;

import 'package:app/domain/ledger_models.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/roles.dart';

export 'package:app/domain/ledger_models.dart';

/// Computes daily cost of goods sold, weighted/latest ingredient valuation,
/// weekly count estimation/reconciliation, and gross/net profit
/// (`computeLedger` in `prototype/index.html`).
LedgerResult computeLedger(PosState s, {String? today}) {
  final tk = today ?? businessDayKey(DateTime.now(), s.shop.dayCutoffMinutes);
  final sh = s.shop;
  final w = sh.childHeadWeight;
  final activeFixedSum = s.fixedCosts
      .where((x) => x.active)
      .fold<double>(0, (acc, x) => acc + x.amount);
  final openDays = math.max(
    1,
    sh.openDaysPerMonth > 0 ? sh.openDaysPerMonth : 30,
  );
  double fixedPerDayFor(DateTime d) {
    if (sh.fixedCostDivisor == 'calendar') {
      final daysInMonth = DateTime(d.year, d.month + 1, 0).day;
      return activeFixedSum / daysInMonth;
    }
    return activeFixedSum / openDays;
  }

  final salesBy = <String, List<BillRecord>>{};
  final purchBy = <String, List<PurchaseRecord>>{};
  final expBy = <String, List<ExpenseRecord>>{};
  for (final b in s.sales) {
    (salesBy[b.date] ??= <BillRecord>[]).add(b);
  }
  for (final p in s.purchases) {
    (purchBy[p.date] ??= <PurchaseRecord>[]).add(p);
  }
  for (final e in s.expenses) {
    (expBy[e.date] ??= <ExpenseRecord>[]).add(e);
  }

  final st = <String, IngredientLedgerState>{};
  for (final ing in s.ingredients) {
    final i0 = s.initialStock[ing.id];
    final c0 = (i0 != null ? i0.cost : ing.lastCost).toDouble();
    st[ing.id] = IngredientLedgerState(
      qty: i0 != null ? i0.qty : 0,
      avg: c0,
      last: c0,
      rate: null,
      sinceUsed: 0,
      sinceHeads: 0,
    );
  }

  final days = <LedgerDaySummary>[];
  final byDate = <String, LedgerDaySummary>{};

  for (
    var d = parseKey(s.startDate);
    dkey(d).compareTo(tk) <= 0;
    d = addDays(d, 1)
  ) {
    final k = dkey(d);
    final fixedPerDay = fixedPerDayFor(d);
    final cnt = s.counts[k];
    final purch = purchBy[k] ?? const <PurchaseRecord>[];
    final closed = cnt != null;

    final sales = (salesBy[k] ?? const <BillRecord>[])
        .where((b) => !b.voided)
        .toList();
    var buffetNet = 0.0;
    var addonNet = 0.0;
    var addonCost = 0.0;
    var gross = 0.0;
    var net = 0.0;
    var a = 0;
    var c = 0;
    var f = 0;

    for (final b in sales) {
      gross += b.total;
      net += b.total - b.vat;
      a += b.heads.a;
      c += b.heads.c;
      f += b.heads.f;
      final k2 = b.subtotal != 0 ? (b.total - b.vat) / b.subtotal : 0.0;
      for (final l in b.lines) {
        final v = l.qty * l.price * k2;
        if (l.type == 'addon') {
          addonNet += v;
          addonCost += l.qty * (l.cost ?? 0);
        } else {
          buffetNet += v;
        }
      }
    }

    final headsW = a + c * w;
    final rows = <IngredientDayRow>[];
    var ingCost = 0.0;

    for (final ing in s.ingredients) {
      final cur =
          st[ing.id] ??
          IngredientLedgerState(
            qty: 0,
            avg: ing.lastCost.toDouble(),
            last: ing.lastCost.toDouble(),
            rate: null,
            sinceUsed: 0,
            sinceHeads: 0,
          );
      var pq = 0.0;
      var pv = 0.0;
      for (final p in purch) {
        for (final l in p.lines) {
          if (l.ingId == ing.id) {
            pq += l.qty;
            pv += l.total;
          }
        }
      }
      final avail = cur.qty + pq;
      final avg = avail > 0
          ? (math.max<double>(cur.qty, 0) * cur.avg + pv) / avail
          : (pq != 0 ? pv / pq : cur.avg);
      final last = pq > 0 ? pv / pq : cur.last;
      final unit = sh.costMethod == 'last' ? last : avg;
      final weekly = ing.countFreq == 'weekly';
      final has = cnt != null && cnt.containsKey(ing.id);

      double? closing;
      double? used;
      double? cost;
      var est = false;
      var next = IngredientLedgerState(
        qty: avail,
        avg: avg,
        last: last,
        rate: cur.rate,
        sinceUsed: cur.sinceUsed,
        sinceHeads: cur.sinceHeads + headsW,
      );

      if (has) {
        closing = cnt[ing.id];
        used = avail - closing!;
        if (!weekly) {
          used = math.max<double>(0, used);
        }
        final tu = cur.sinceUsed + used;
        final th = cur.sinceHeads + headsW;
        next = IngredientLedgerState(
          qty: closing,
          avg: avg,
          last: last,
          rate: th > 0 ? math.max<double>(0, tu) / th : cur.rate,
          sinceUsed: 0,
          sinceHeads: 0,
        );
      } else if (closed && weekly) {
        est = true;
        used = cur.rate == null
            ? 0
            : math.min<double>(math.max<double>(avail, 0), cur.rate! * headsW);
        closing = avail - used;
        next = IngredientLedgerState(
          qty: closing,
          avg: avg,
          last: last,
          rate: cur.rate,
          sinceUsed: cur.sinceUsed + used,
          sinceHeads: cur.sinceHeads + headsW,
        );
      }

      if (used != null) {
        cost = used * unit;
        ingCost += cost;
      }
      st[ing.id] = next;
      rows.add(
        IngredientDayRow(
          ing: ing,
          opening: cur.qty,
          pq: pq,
          pv: pv,
          avail: avail,
          avg: avg,
          unit: unit,
          closing: closing,
          used: used,
          cost: cost,
          est: est,
          weekly: weekly,
          rate: cur.rate,
        ),
      );
    }

    final expenses = (expBy[k] ?? const <ExpenseRecord>[]).fold<double>(
      0,
      (acc, e) => acc + e.amount,
    );
    final fixed = sales.isNotEmpty ? fixedPerDay : 0.0;
    final profit = closed ? net - ingCost - addonCost : null;
    final day = LedgerDaySummary(
      date: k,
      closed: closed,
      isToday: k == tk,
      bills: sales.length,
      a: a,
      c: c,
      f: f,
      heads: a + c,
      headsW: headsW,
      gross: gross,
      net: net,
      buffetNet: buffetNet,
      addonNet: addonNet,
      addonCost: addonCost,
      purchases: purch.fold<double>(
        0,
        (acc, p) => acc + p.lines.fold<double>(0, (s2, l) => s2 + l.total),
      ),
      expenses: expenses,
      fixed: fixed,
      ingCost: closed ? ingCost : null,
      profit: profit,
      netProfit: closed && profit != null ? profit - expenses - fixed : null,
      costPerHead: closed && headsW != 0 ? ingCost / headsW : null,
      foodPct: closed && buffetNet != 0 ? ingCost / buffetNet * 100 : null,
      estItems: rows.where((r) => r.est).length,
      rows: rows,
    );
    days.add(day);
    byDate[k] = day;
  }

  return LedgerResult(days: days, byDate: byDate, current: st);
}
