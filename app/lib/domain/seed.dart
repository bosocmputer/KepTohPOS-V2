import 'dart:math' as math;

import 'package:app/domain/models.dart';
import 'package:app/domain/order_calc.dart';
import 'package:app/domain/roles.dart';
import 'package:app/domain/settle.dart';

int _imul32(int a, int b) {
  final ah = (a >> 16) & 0xFFFF;
  final al = a & 0xFFFF;
  final bh = (b >> 16) & 0xFFFF;
  final bl = b & 0xFFFF;
  return (al * bl + (((ah * bl + al * bh) & 0xFFFF) << 16)).toSigned(32);
}

int _ushr32(int x, int shift) => x.toUnsigned(32) >> shift;

/// Deterministic 32-bit PRNG matching JS `rng(seed)` in `prototype/index.html`.
double Function() rng(int initialSeed) {
  var state = initialSeed.toSigned(32);
  return () {
    state = (state + 0x6D2B79F5).toSigned(32);
    var t = _imul32(state ^ _ushr32(state, 15), 1 | state);
    t = (t + _imul32(t ^ _ushr32(t, 7), 61 | t)) ^ t;
    return _ushr32(t ^ _ushr32(t, 14), 0) / 4294967296.0;
  };
}

/// Ensures open table defaults (`migrate` in `prototype/index.html`).
PosState migrate(PosState o) {
  o.version = 2;
  return o;
}

DateTime _atHours(DateTime d, double hh) {
  final mins = (hh * 60 + 0.5).floor();
  return DateTime(d.year, d.month, d.day, 0, mins);
}

/// Generates 30 days of historical sales, purchases, expenses, counts, shifts,
/// and active tables (`seed()` in `prototype/index.html`).
PosState seed({
  required ShopConfig shop,
  required List<PackageItem> packages,
  required List<AddonItem> addons,
  required List<SupplierItem> suppliers,
  required List<IngredientItem> ingredients,
  required List<DiningTable> tables,
  required List<StaffMember> staff,
  required List<PaymentMethod> payments,
  required List<ExpenseType> expenseTypes,
  required List<FixedCostItem> fixedCosts,
  String currentStaffId = 'st1',
  int rngSeed = 20261103,
  DateTime? now,
}) {
  final rand = rng(rngSeed);
  final currentNow = now ?? DateTime.now();
  final start = addDays(currentNow, -30);

  final s = PosState(
    startDate: dkey(start),
    currentStaffId: currentStaffId,
    shop: shop,
    packages: List<PackageItem>.from(packages),
    addons: addons.map((a) => a.copy()).toList(),
    suppliers: List<SupplierItem>.from(suppliers),
    ingredients: List<IngredientItem>.from(ingredients),
    tables: List<DiningTable>.from(tables),
    staff: List<StaffMember>.from(staff),
    payments: List<PaymentMethod>.from(payments),
    expenseTypes: List<ExpenseType>.from(expenseTypes),
    fixedCosts: List<FixedCostItem>.from(fixedCosts),
  );

  final sim = <String, double>{};
  for (final ing in s.ingredients) {
    final q = roundQty(ing.par * 0.25, ing.unit);
    s.initialStock[ing.id] = StockLot(qty: q, cost: ing.lastCost);
    sim[ing.id] = q;
  }

  T pick<T>(List<T> arr) => arr[(rand() * arr.length).floor()];
  var seqId = 0;
  String nextId(String prefix) => '$prefix${++seqId}';

  for (var i = 30; i >= 0; i--) {
    final day = addDays(currentNow, -i);
    final k = dkey(day);
    final isToday = i == 0;
    final dow = day.weekday % 7; // 0 = Sunday .. 6 = Saturday (JS getDay())
    final factor = (dow == 5 || dow == 6) ? 1.45 : (dow == 0 ? 1.25 : 1.0);

    // Morning purchases
    final bySup = <String, List<PurchaseLine>>{};
    for (final ing in s.ingredients) {
      final curSim = sim[ing.id] ?? 0;
      final need = 95 * factor * ing.use * 1.15 - curSim;
      if (need <= 0) continue;
      final step = ing.unit == 'ฟอง'
          ? 30.0
          : (kCountUnits.contains(ing.unit) ? 1.0 : 0.5);
      final qty = (need / step).ceil() * step;
      final price = ing.lastCost * (0.95 + rand() * 0.1);
      (bySup[ing.supplierId] ??= <PurchaseLine>[]).add(
        PurchaseLine(
          ingId: ing.id,
          qty: r2(qty),
          total: (qty * price + 0.5).floorToDouble(),
        ),
      );
      sim[ing.id] = curSim + qty;
    }

    var supIdx = 0;
    for (final entry in bySup.entries) {
      s.purchases.add(
        PurchaseRecord(
          id: nextId('p'),
          date: k,
          at: _atHours(day, 9 + supIdx * 0.6).toUtc().toIso8601String(),
          supplierId: entry.key,
          lines: entry.value,
        ),
      );
      supIdx++;
    }

    // Daily operating expenses
    final expItems = <(String, double)>[
      ('et2', 60),
      ('et3', 40),
      if (i % 3 == 0) ('et1', 420),
    ];
    for (var j = 0; j < expItems.length; j++) {
      s.expenses.add(
        ExpenseRecord(
          id: nextId('e'),
          date: k,
          at: _atHours(day, 10 + j * 0.2).toUtc().toIso8601String(),
          typeId: expItems[j].$1,
          amount: expItems[j].$2,
        ),
      );
    }

    // Shift (today's openedAt must never exceed currentNow)
    final pickedCashier = pick(<String>['st3', 'st4']);
    final cashier = s.staff.any((x) => x.id == pickedCashier)
        ? pickedCashier
        : 'st3';
    final shiftOpen = isToday
        ? DateTime.fromMillisecondsSinceEpoch(
            (currentNow.millisecondsSinceEpoch - (4.5 * 3600000).round()).clamp(
              _atHours(day, 0).millisecondsSinceEpoch,
              currentNow.millisecondsSinceEpoch,
            ),
          )
        : _atHours(day, 16);
    final shift = ShiftRecord(
      id: nextId('sh'),
      staffId: cashier,
      openedAt: shiftOpen.toUtc().toIso8601String(),
      floatAmount: 1000,
    );
    s.shifts.add(shift);

    // Sales
    final groups = isToday ? 9 : ((22 + rand() * 8) * factor + 0.5).floor();
    var eq = 0.0;
    for (var g = 0; g < groups; g++) {
      final size = 2 + (rand() * 5).floor();
      var kids = rand() < 0.3 ? 1 + (rand() * 2).floor() : 0;
      kids = math.min(kids, size - 1);
      final free = (kids > 0 && rand() < 0.4) ? 1 : 0;
      final c = kids - free;
      final a = size - kids;
      final pkg = rand() < 0.78 ? s.packages[0] : s.packages[1];
      final ad = <AddonLineInput>[
        AddonLineInput(
          addon: s.addons[0],
          qty: (size * 0.5 * rand() + 0.5).floor(),
        ),
        AddonLineInput(addon: s.addons[1], qty: 1),
        AddonLineInput(
          addon: s.addons[2],
          qty: rand() < 0.4 ? 1 + (rand() * 2).floor() : 0,
        ),
        AddonLineInput(addon: s.addons[3], qty: rand() < 0.2 ? 2 : 0),
        AddonLineInput(
          addon: pick(<AddonItem>[s.addons[4], s.addons[5], s.addons[6]]),
          qty: rand() < 0.55 ? 1 + (rand() * 4).floor() : 0,
        ),
      ];
      final order = calcOrder(s.shop, pkg, a, c, free, ad);
      final pr = rand();
      final method = pr < 0.55
          ? s.payments[1]
          : (pr < 0.95 ? s.payments[0] : s.payments[2]);
      final DateTime t;
      if (isToday) {
        final minMs = _atHours(day, 0.1).millisecondsSinceEpoch;
        final calcMs =
            (currentNow.millisecondsSinceEpoch - (3.2 - g * 0.32) * 3600000)
                .round();
        t = DateTime.fromMillisecondsSinceEpoch(math.max(minMs, calcMs));
      } else {
        t = _atHours(day, 16.5 + rand() * 5);
      }
      final received =
          (order.total / 100).ceil() * 100.0 + (rand() < 0.3 ? 500 : 0);
      final b = makeBill(
        s,
        id: nextId('b'),
        at: t.toUtc().toIso8601String(),
        tableId: s.tables[(g * 5 + i) % 12].id,
        staffId: cashier,
        shiftId: shift.id,
        packageId: pkg.id,
        order: order,
        method: method,
        received: received,
      );
      if (isToday && g >= groups - 4) {
        const activeIndices = <int>[0, 2, 5, 9];
        final tid = s.tables[activeIndices[g - (groups - 4)]].id;
        b
          ..tableId = tid
          ..tableName = s.tables.firstWhere((x) => x.id == tid).name;
        s.openTables[tid] = OpenTableState(
          openedAt: b.at,
          packageId: pkg.id,
          billIds: <String>[b.id],
          heads: HeadsCount(a: a, c: c, f: free),
        );
      }
      eq += a + c * 0.6 + free * 0.3;
    }

    if (!isToday) {
      final cnt = <String, double>{};
      for (final ing in s.ingredients) {
        final used = eq * ing.use * (0.88 + rand() * 0.25);
        final nextSim = roundQty(
          math.max(0, (sim[ing.id] ?? 0) - used),
          ing.unit,
        );
        sim[ing.id] = nextSim;
        if (ing.countFreq != 'weekly' || dow == s.shop.weeklyCountDow) {
          cnt[ing.id] = nextSim;
        }
      }
      s.counts[k] = cnt;
      final cash = s.sales
          .where((b) => b.shiftId == shift.id && b.methodType == 'cash')
          .fold<double>(0, (acc, b) => acc + b.total);
      shift.closedAt = _atHours(day, 23).toUtc().toIso8601String();
      final diff = rand() < 0.75 ? 0 : ((rand() - 0.5) * 40 + 0.5).floor();
      shift.counted = 1000 + cash + diff;
    }
  }

  // Example unpaid eat-before-paying table (A4)
  final dueTable = s.tables[3];
  if (!s.openTables.containsKey(dueTable.id)) {
    final openedAt = DateTime.fromMillisecondsSinceEpoch(
      currentNow.millisecondsSinceEpoch - 38 * 60000,
    ).toUtc().toIso8601String();
    s.openTables[dueTable.id] = OpenTableState(
      openedAt: openedAt,
      packageId: 'pk1',
      timing: 'after',
      notes: 'ลูกค้าแพ้กุ้ง 1 ท่าน',
      heads: HeadsCount(a: 3, c: 1),
      rounds: <TableRound>[
        TableRound(
          id: nextId('r'),
          at: openedAt,
          staffId: 'st3',
          a: 3,
          c: 1,
          f: 0,
          ad: <String, int>{'ad1': 2, 'ad5': 2},
        ),
      ],
    );
  }

  return migrate(s);
}
