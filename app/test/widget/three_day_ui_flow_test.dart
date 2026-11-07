import 'dart:io';

import 'package:app/app.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PosRepository _buildFullRepo({required DateTime fixedNow}) {
  const keys = [
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
  ];
  final jsonByName = {
    for (final k in keys) k: File('assets/mock/$k.json').readAsStringSync(),
  };
  return MockPosRepository.fromJsonStrings(
    jsonByName,
    now: fixedNow,
    sessionStaffId: 'st1',
  );
}

Future<void> _tapK(WidgetTester t, String k) async {
  final f = find.byKey(ValueKey(k));
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _navTo(WidgetTester t, String viewId) async {
  await _tapK(t, 'shell-menu-btn');
  await _tapK(t, 'drawer-nav-$viewId');
}

Future<void> _tapStepper(WidgetTester t, String k, String s, int n) async {
  final btn = find.descendant(
    of: find.byKey(ValueKey(k)),
    matching: find.bySemanticsLabel(s),
  );
  for (var i = 0; i < n; i++) {
    await t.tap(btn);
    await t.pumpAndSettle();
  }
}

void _sell(
  PosState s,
  int tIdx,
  TableTotals cart,
  StaffMember by,
  String pkg,
  int pmIdx,
  int rec,
  String id,
  DateTime now, {
  String timing = 'before',
}) {
  settle(
    s,
    s.tables[tIdx],
    cart,
    by,
    timing: timing,
    pkgId: pkg,
    method: s.payments[pmIdx],
    received: rec,
    billId: id,
    now: now,
  );
  s.openTables.remove(s.tables[tIdx].id);
}

PurchaseLine _pl(String id, double q, int tot) =>
    PurchaseLine(ingId: id, qty: q, total: tot);

void _addExp(PosState s, String id, String d, String at, int amt) =>
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

void _seedDay1Remainder(PosState s, DateTime now) {
  final dKey = dkey(now);
  final isoNow = now.toUtc().toIso8601String();
  final manager = s.staff.firstWhere((x) => x.role == 'manager');
  final cashier = s.staff.firstWhere((x) => x.role == 'cashier');
  savePurchase(
    s,
    date: dKey,
    supplierId: 's1',
    me: manager,
    note: 'รับของวันแรก',
    now: now,
    lines: [
      _pl('i1', 20, 360000),
      _pl('i2', 10, 170000),
      _pl('i6', 8, 176000),
      _pl('i9', 15, 52500),
      _pl('i11', 5, 30000),
      _pl('i13', 10, 70000),
      _pl('i15', 30, 54000),
    ],
  );
  _addExp(s, 'ex_d1', dKey, isoNow, 35000);
  final r1 = TableTotals(a: 6, ad: {'ad5': 4});
  sendRound(s, s.tables[1], r1, cashier, 'after', 'pk2', '', now: now);
  adjustSent(s, s.tables[1].id, 'addon', 'ad5', 1, 'ลด', manager, now: now);
  final empty = TableTotals();
  _sell(s, 1, empty, cashier, 'pk2', 1, 191400, 'b_d1_2', now, timing: 'after');
  final c3 = TableTotals(a: 8, c: 2, ad: {'ad2': 3});
  _sell(s, 2, c3, cashier, 'pk2', 2, 257000, 'b_d1_3', now);
  const d1Counts = {
    'i1': '14',
    'i2': '7',
    'i6': '5',
    'i9': '10',
    'i11': '4',
    'i13': '8',
    'i15': '24',
  };
  saveDailyCount(s, date: dKey, draftValues: d1Counts);
}

void _seedRemainingDays(PosState s, DateTime now) {
  final dKey = dkey(now);
  final isoNow = now.toUtc().toIso8601String();
  final isoEnd = now.add(const Duration(hours: 4)).toUtc().toIso8601String();
  final owner = s.staff.firstWhere((x) => x.role == 'owner');
  final manager = s.staff.firstWhere((x) => x.role == 'manager');
  final cashier = s.staff.firstWhere((x) => x.role == 'cashier');

  s.shifts.add(
    ShiftRecord(
      id: 'sh_d2',
      staffId: cashier.id,
      openedAt: isoNow,
      floatAmount: 100000,
    ),
  );
  savePurchase(
    s,
    date: dKey,
    supplierId: 's1',
    me: manager,
    note: 'รับของวันที่ 2',
    now: now,
    lines: [_pl('i1', 6, 132000), _pl('i6', 5, 130000)],
  );
  _addExp(s, 'ex_d2', dKey, isoNow, 50000);
  final c1 = TableTotals(a: 10, c: 4, ad: {'ad1': 6});
  final c2 = TableTotals(a: 11, c: 2, ad: {'ad3': 5});
  final c3 = TableTotals(a: 2, ad: {'ad5': 2});
  _sell(s, 0, c1, cashier, 'pk2', 0, 350000, 'b_d2_1', now);
  _sell(s, 3, c2, cashier, 'pk1', 1, 251200, 'b_d2_2', now);
  _sell(s, 4, c3, cashier, 'pk1', 0, 60000, 'b_d2_void', now);
  voidBill(s, billId: 'b_d2_void', me: manager, reason: 'ย้ายโต๊ะ', now: now);
  const d2Counts = {'i1': '12', 'i2': '3', 'i6': '6', 'i9': '4'};
  saveDailyCount(s, date: dKey, draftValues: d2Counts);
  s.shifts.last
    ..closedAt = isoEnd
    ..counted = 441600
    ..closedBy = manager.id;

  advanceSimulationDayInState(s);
  s.shifts.add(
    ShiftRecord(
      id: 'sh_d3',
      staffId: owner.id,
      openedAt: isoNow,
      floatAmount: 100000,
    ),
  );
  _sell(s, 0, TableTotals(a: 6), owner, 'pk1', 0, 120000, 'b_d3_1', now);
  final c4 = TableTotals(a: 4, ad: {'ad1': 2});
  _sell(s, 1, c4, owner, 'pk2', 1, 114600, 'b_d3_2', now);
  _addExp(s, 'ex_d3', dKey, isoNow, 40000);
  const d3Counts = {
    'i1': '9',
    'i2': '1.5',
    'i6': '4.5',
    'i9': '2',
    'i11': '2',
    'i13': '4',
    'i15': '13',
  };
  saveDailyCount(s, date: dKey, draftValues: d3Counts);
  s.shifts.last
    ..closedAt = isoEnd
    ..counted = 219400
    ..closedBy = owner.id;
}

void main() {
  testWidgets(
    '3-Day UI E2E Flow: Setup -> Shift -> Sale -> Bills -> Stock -> Reports',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final now = DateTime(2026, 11, 6, 18);
      final repo = _buildFullRepo(fixedNow: now);
      await tester.pumpWidget(
        KepTohApp(repository: repo, now: now, initialLocation: '/setup'),
      );
      await tester.pumpAndSettle();

      // 1. UI: Clear daily transactions via Setup -> Demo -> Confirm Modal
      await _tapK(tester, 'setup-tab-demo');
      await _tapK(tester, 'setup-clear-daily-btn');
      expect(find.text('เริ่มข้อมูลรายวันใหม่ (0 บิล)?'), findsOneWidget);
      await tester.tap(find.text('เริ่มรายวันใหม่'));
      await tester.pumpAndSettle();
      expect(repo.state.sales, isEmpty);

      // 2. UI: Navigate to Shift page and open shift with ฿1,000 preset
      await _navTo(tester, 'shift');
      await _tapK(tester, 'shift-float-preset-1000');
      await _tapK(tester, 'open-shift-submit-btn');
      expect(find.byKey(const ValueKey('active-shift-card')), findsOneWidget);

      // 3. UI: Navigate to Tables & sell Table A1 (Multi-Gen: 4A + 2C + 1F)
      await _navTo(tester, 'tables');
      await _tapK(tester, 'table-card-t1');
      await _tapStepper(tester, 'people-stepper-a', 'เพิ่ม', 2);
      await _tapStepper(tester, 'people-stepper-c', 'เพิ่ม', 2);
      await _tapStepper(tester, 'people-stepper-f', 'เพิ่ม', 1);
      await tester.tap(find.text('เครื่องดื่ม'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('addon-card-ad1')));
      }
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const ValueKey('addon-card-ad3')));
      }
      await tester.pumpAndSettle();
      expect(find.text('฿1,104'), findsWidgets);

      await _tapK(tester, 'sale-pay-btn');
      await _tapK(tester, 'quick-cash-1200');
      expect(find.text('฿96'), findsOneWidget);
      await _tapK(tester, 'pay-confirm-btn');
      await _tapK(tester, 'receipt-done-btn');

      // Re-open occupied pay-before table A1 and close it via banner button
      await _tapK(tester, 'table-card-t1');
      await _tapK(tester, 'banner-close-table-btn');
      final confirmClose = find.descendant(
        of: find.byType(Confirm),
        matching: find.text('เก็บโต๊ะ'),
      );
      await tester.tap(confirmClose);
      await tester.pumpAndSettle();

      repo.update((s) => _seedDay1Remainder(s, now));
      await tester.pumpAndSettle();

      await _navTo(tester, 'shift');
      await _tapK(tester, 'shift-fill-expected-btn');
      await _tapK(tester, 'close-shift-btn');
      await tester.tap(
        find.descendant(of: find.byType(Confirm), matching: find.text('ปิดกะ')),
      );
      await tester.pumpAndSettle();

      await _navTo(tester, 'setup');
      await _tapK(tester, 'setup-tab-demo');
      await _tapK(tester, 'setup-advance-day-btn');
      await tester.tap(find.text('ข้ามไปวันถัดไป'));
      await tester.pumpAndSettle();

      repo.update((s) => _seedRemainingDays(s, now));
      await tester.pumpAndSettle();

      await _navTo(tester, 'dashboard');
      for (final v in ['฿13,876', '฿7,978', '฿5,549', '฿-311']) {
        expect(find.text(v), findsWidgets);
      }
      await _navTo(tester, 'reports');
      expect(find.text('ปิดยอดแล้ว 3/3 วัน'), findsWidgets);
      expect(find.text('฿11,745'), findsWidgets);
    },
  );
}
