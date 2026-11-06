import 'dart:io';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('3-Day Real-World POS Simulation: Math & Accounting Audit', () async {
    final now = DateTime(2026, 11, 6, 18);
    final jsonByName = <String, String>{
      for (final k in const [
        'shop',
        'packages',
        'addons',
        'suppliers',
        'ingredients',
        'tables',
        'staff',
        'payments',
        'expense_types',
        'fixed_costs',
      ])
        k: await File('assets/mock/$k.json').readAsString(),
    };
    final repo = MockPosRepository.fromJsonStrings(
      jsonByName,
      now: now,
      sessionStaffId: 'st1',
    );
    final setupCubit = SetupCubit(repo, now: now);
    final owner = repo.state.staff.firstWhere((x) => x.role == 'owner');
    final manager = repo.state.staff.firstWhere((x) => x.role == 'manager');
    final cashier = repo.state.staff.firstWhere((x) => x.role == 'cashier');

    void sell(
      PosState s,
      int tIdx,
      int a,
      int c,
      int f,
      Map<String, int> ad,
      String pkg,
      int pmIdx,
      double rec,
      String id, {
      String timing = 'before',
      StaffMember? by,
    }) {
      settle(
        s,
        s.tables[tIdx],
        TableTotals(a: a, c: c, f: f, ad: ad),
        by ?? cashier,
        timing: timing,
        pkgId: pkg,
        method: s.payments[pmIdx],
        received: rec,
        billId: id,
        now: now,
      );
      s.openTables.remove(s.tables[tIdx].id);
    }

    PurchaseLine pl(String id, double q, double tot) =>
        PurchaseLine(ingId: id, qty: q, total: tot);
    void addExp(PosState s, String id, String d, String at, double amt) =>
        s.expenses.add(
          ExpenseRecord(
            id: id,
            date: d,
            at: at,
            typeId: s.expenseTypes.first.id,
            amount: amt,
            note: id,
          ),
        );

    // STEP 0: Clear all daily transactions to 0 (Clean Slate)
    setupCubit.clearDailyTransactions();
    expect(repo.state.sales, isEmpty);
    expect(repo.state.purchases, isEmpty);
    expect(repo.state.counts, isEmpty);
    expect(repo.state.shifts, isEmpty);
    expect(repo.state.expenses, isEmpty);

    // DAY 1: Baseline Profit + Weekly Rate Setup
    final dKey = dkey(now);
    final isoNow = now.toUtc().toIso8601String();
    final isoEnd = now.add(const Duration(hours: 4)).toUtc().toIso8601String();
    repo.update((s) {
      s.shifts.add(
        ShiftRecord(
          id: 'sh_d1',
          staffId: cashier.id,
          openedAt: isoNow,
          floatAmount: 1000,
        ),
      );
      savePurchase(
        s,
        date: dKey,
        supplierId: 's1',
        me: manager,
        note: 'รับของวันแรก',
        now: now,
        lines: [
          pl('i1', 20, 3600),
          pl('i2', 10, 1700),
          pl('i6', 8, 1760),
          pl('i9', 15, 525),
          pl('i11', 5, 300),
          pl('i13', 10, 700),
          pl('i15', 30, 540),
        ],
      );
      addExp(s, 'ex_d1', dKey, isoNow, 350);
      sell(s, 0, 4, 2, 1, {'ad1': 4, 'ad3': 2}, 'pk1', 0, 1200, 'b_d1_1');
      sendRound(
        s,
        s.tables[1],
        TableTotals(a: 6, ad: {'ad5': 4}),
        cashier,
        'after',
        'pk2',
        '',
        now: now,
      );
      adjustSent(
        s,
        s.tables[1].id,
        'addon',
        'ad5',
        1,
        'คีย์เกิน 1 ขวด',
        manager,
        now: now,
      );
      sell(s, 1, 0, 0, 0, const {}, 'pk2', 1, 1914, 'b_d1_2', timing: 'after');
      sell(s, 2, 8, 2, 0, {'ad2': 3}, 'pk2', 2, 2570, 'b_d1_3');
      saveDailyCount(
        s,
        date: dKey,
        draftValues: const {
          'i1': '14',
          'i2': '7',
          'i6': '5',
          'i9': '10',
          'i11': '4',
          'i13': '8',
          'i15': '24',
        },
      );
    });

    // Guard check: cannot advance simulation day while shift is still open
    final blockedShiftRes = setupCubit.advanceSimulationDay();
    expect((blockedShiftRes.ok, blockedShiftRes.isGuardBlock), (false, true));

    repo.update((s) {
      s.shifts.first
        ..closedAt = isoEnd
        ..counted = 2104
        ..closedBy = cashier.id;
    });

    final l1 = computeLedger(repo.state, today: dKey).byDate[dKey]!;
    expect((l1.bills, l1.heads, l1.headsW), (3, 22, 20.0));
    expect((l1.gross, l1.buffetNet, l1.addonNet), (5588.0, 5178.0, 410.0));
    expect((l1.addonCost, l1.ingCost, l1.profit), (236.0, 2733.0, 2619.0));
    expect(l1.costPerHead, closeTo(136.65, 0.01));
    expect(l1.foodPct, closeTo(52.78, 0.01));
    expect(l1.netProfit, closeTo(732.33, 0.01));
    final sh1 = calcShiftStats(repo.state, repo.state.shifts.first);
    expect(sh1.expected, 2104.0);

    // DAY 2: Price Spike (Weighted Avg vs Last) + Weekly Estimation + Void
    expect(setupCubit.advanceSimulationDay().ok, isTrue);
    repo.update((s) {
      s.shifts.add(
        ShiftRecord(
          id: 'sh_d2',
          staffId: cashier.id,
          openedAt: isoNow,
          floatAmount: 1000,
        ),
      );
      savePurchase(
        s,
        date: dKey,
        supplierId: 's1',
        me: manager,
        note: 'รับของวันที่ 2',
        now: now,
        lines: [pl('i1', 6, 1320), pl('i6', 5, 1300)],
      );
      addExp(s, 'ex_d2', dKey, isoNow, 500);
      sell(s, 0, 10, 4, 0, {'ad1': 6}, 'pk2', 0, 3500, 'b_d2_1');
      sell(s, 3, 11, 2, 0, {'ad3': 5}, 'pk1', 1, 2512, 'b_d2_2');
      sell(s, 4, 2, 0, 0, {'ad5': 2}, 'pk1', 0, 600, 'b_d2_void');
      voidBill(
        s,
        billId: 'b_d2_void',
        me: manager,
        reason: 'ย้ายโต๊ะ',
        now: now,
      );
      saveDailyCount(
        s,
        date: dKey,
        draftValues: const {'i1': '12', 'i2': '3', 'i6': '6', 'i9': '4'},
      );
      s.shifts.last
        ..closedAt = isoEnd
        ..counted = 4416
        ..closedBy = manager.id;
    });

    final l2 = computeLedger(repo.state, today: dKey).byDate[dKey]!;
    expect((l2.bills, l2.heads, l2.headsW, l2.estItems), (2, 27, 24.0, 4));
    expect(
      (l2.gross, l2.buffetNet, l2.addonNet, l2.addonCost),
      (5948.0, 5733.0, 215.0, 101.0),
    );
    expect(l2.ingCost, closeTo(3755.6, 0.01));
    expect(l2.costPerHead, closeTo(156.48, 0.01));
    expect(l2.foodPct, closeTo(65.51, 0.01));
    expect(l2.profit, closeTo(2091.4, 0.01));
    expect(l2.netProfit, closeTo(54.73, 0.01));
    final sh2 = calcShiftStats(repo.state, repo.state.shifts.last);
    expect((repo.state.shifts.last.counted ?? 0) - sh2.expected, -20.0);

    // DAY 3: Weekly Reconciliation + Low-Volume Net Loss Day
    expect(setupCubit.advanceSimulationDay().ok, isTrue);
    repo.update((s) {
      s.shifts.add(
        ShiftRecord(
          id: 'sh_d3',
          staffId: owner.id,
          openedAt: isoNow,
          floatAmount: 1000,
        ),
      );
      sell(s, 0, 6, 0, 0, const {}, 'pk1', 0, 1200, 'b_d3_1', by: owner);
      sell(s, 1, 4, 0, 0, {'ad1': 2}, 'pk2', 1, 1146, 'b_d3_2', by: owner);
      addExp(s, 'ex_d3', dKey, isoNow, 400);
      saveDailyCount(
        s,
        date: dKey,
        draftValues: const {
          'i1': '9',
          'i2': '1.5',
          'i6': '4.5',
          'i9': '2',
          'i11': '2',
          'i13': '4',
          'i15': '13',
        },
      );
      s.shifts.last
        ..closedAt = isoEnd
        ..counted = 2194
        ..closedBy = owner.id;
    });

    final ledgerAvg = computeLedger(repo.state, today: dKey);
    final l3 = ledgerAvg.byDate[dKey]!;
    expect((l3.bills, l3.heads, l3.headsW), (2, 10, 10.0));
    expect(
      (l3.gross, l3.buffetNet, l3.addonNet, l3.addonCost),
      (2340.0, 2310.0, 30.0, 12.0),
    );
    expect(l3.ingCost, closeTo(1489.4, 0.01));
    expect(l3.costPerHead, closeTo(148.94, 0.01));
    expect(l3.foodPct, closeTo(64.48, 0.01));
    expect(l3.profit, closeTo(838.6, 0.01));
    expect(l3.netProfit, closeTo(-1098.07, 0.01));

    final dashAvg = computeDashboardSummary(repo.state, ledgerAvg, today: dKey);
    expect((dashAvg.net, dashAvg.addonCost), (13876.0, 349.0));
    expect(dashAvg.ingCost, closeTo(7978.0, 0.01));
    expect(dashAvg.profit, closeTo(5549.0, 0.01));
    expect(dashAvg.netProfit, closeTo(-311.0, 0.01));

    setupCubit.saveCosting(repo.state.shop.copyWith(costMethod: 'last'));
    final ledgerLast = computeLedger(repo.state, today: dKey);
    expect(
      ledgerLast.days[1].ingCost! - ledgerAvg.days[1].ingCost!,
      closeTo(304.0, 0.01),
    );
    setupCubit.saveCosting(repo.state.shop.copyWith(costMethod: 'avg'));
    await setupCubit.close();
    await repo.dispose();
  });
}
