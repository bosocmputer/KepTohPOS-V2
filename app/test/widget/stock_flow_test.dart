import 'dart:io';

import 'package:app/app.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PosRepository _buildFullStockRepo({
  required DateTime fixedNow,
  String sessionStaffId = 'st1',
}) {
  const keys = <String>[
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
  final jsonByName = <String, String>{
    for (final k in keys) k: File('assets/mock/$k.json').readAsStringSync(),
  };
  return MockPosRepository.fromJsonStrings(
    jsonByName,
    now: fixedNow,
    sessionStaffId: sessionStaffId,
  );
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 12);

  testWidgets('Stock count flow: count all 11 due items using only NumPad + '
      '"รายการถัดไป" (without tapping rows) -> "บันทึกและปิดวัน" -> '
      '/login latest closed day net profit updates', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _buildFullStockRepo(fixedNow: fixedNow);
    final authCubit = AuthCubit(repo);
    addTearDown(authCubit.close);

    // Before closing 2026-11-04, latest closed day is 2026-11-03 (15,299 ฿)
    expect(authCubit.state.lastClosedDay?.date, '2026-11-03');
    expect(r2(authCubit.state.heroProfitValue), 15298.97);

    await tester.pumpWidget(
      KepTohApp(
        repository: repo,
        authCubit: authCubit,
        initialLocation: '/stock',
      ),
    );
    await tester.pumpAndSettle();

    // Save button is initially disabled (0/11 due items counted)
    final saveBtnFinder = find.byKey(const ValueKey('stock-count-save-btn'));
    expect(tester.widget<Btn>(saveBtnFinder).disabled, isTrue);
    expect(find.textContaining('นับแล้ว 0/11'), findsOneWidget);

    final padScope = find.byKey(const ValueKey('stock-count-pad'));
    final digit5Finder = find.descendant(
      of: padScope,
      matching: find.text('5'),
    );
    final nextBtnFinder = find.byKey(const ValueKey('stock-count-next-btn'));

    // Count all 11 due items using ONLY NumPad + "รายการถัดไป"
    for (var i = 0; i < 11; i++) {
      await tester.tap(digit5Finder);
      await tester.pump();
      if (i < 10) {
        await tester.tap(nextBtnFinder);
        await tester.pumpAndSettle();
      }
    }

    // All 11 due items are now counted -> Save button is enabled
    expect(find.textContaining('นับแล้ว 11/11'), findsOneWidget);
    expect(tester.widget<Btn>(saveBtnFinder).disabled, isFalse);

    // Tap "บันทึกและปิดวัน"
    await tester.tap(saveBtnFinder);
    await tester.pump();

    expect(find.text('บันทึกยอดคงเหลือและปิดวันแล้ว'), findsOneWidget);
    expect(repo.state.counts.containsKey('2026-11-04'), isTrue);

    // Dismiss toast timer and sign out to /login to inspect summary card
    await tester.pump(const Duration(seconds: 3));
    authCubit.logout();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('login-hero-ledger-card')),
      findsOneWidget,
    );
    expect(find.text('ตัวอย่างปิดยอดล่าสุด · 4 พ.ย.'), findsOneWidget);
    expect(authCubit.state.lastClosedDay?.date, '2026-11-04');
    expect(authCubit.state.heroProfitValue, isNot(equals(15298.97)));
  });

  testWidgets(
    'Cashier role hides edit/delete buttons in purchases & expenses, while '
    'Balance tab switches list/grid and filters via StockFilterDrawer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // st3 is cashier
      final repo = _buildFullStockRepo(
        fixedNow: fixedNow,
        sessionStaffId: 'st3',
      );
      await tester.pumpWidget(
        KepTohApp(repository: repo, initialLocation: '/stock'),
      );
      await tester.pumpAndSettle();

      // Switch to ซื้อของ tab
      await tester.tap(find.text('ซื้อของ'));
      await tester.pumpAndSettle();
      expect(find.text('รับของเข้า'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsNothing);

      // Switch to ค่าใช้จ่าย tab
      await tester.tap(find.text('ค่าใช้จ่าย'));
      await tester.pumpAndSettle();
      expect(find.text('เพิ่มค่าใช้จ่าย'), findsOneWidget);

      // Switch to คงเหลือ tab -> toggle Grid / List and open Filter Drawer
      await tester.tap(find.text('คงเหลือ'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('balance-total-value')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('stock-view-grid-btn')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('balance-grid-card-i1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('stock-filter-btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stock-filter-drawer')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('stock-filter-loc-freezer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stock-filter-apply-btn')));
      await tester.pumpAndSettle();
      expect(find.text('ตัวกรอง (1)'), findsOneWidget);
    },
  );
}
