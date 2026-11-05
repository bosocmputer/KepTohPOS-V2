import 'dart:io';

import 'package:app/app.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/bills/presentation/pages/bills_page.dart';
import 'package:app/features/tables/presentation/pages/tables_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

PosRepository _buildFullRepo({
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

  testWidgets(
    'Dashboard: tap bar shows profit; tap go-stock navigates to /stock',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _buildFullRepo(fixedNow: fixedNow);
      await tester.pumpWidget(
        KepTohApp(
          repository: repo,
          now: fixedNow,
          initialLocation: '/dashboard',
        ),
      );
      await tester.pumpAndSettle();

      // Verify hero card & unclosed today banner are visible
      expect(find.byKey(const ValueKey('dashboard-hero-card')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dashboard-today-open-banner')),
        findsOneWidget,
      );
      expect(find.text('วันนี้ยังไม่ปิดยอด'), findsOneWidget);

      // Initially no chart bar is selected
      expect(
        find.byKey(const ValueKey('profit-chart-selected-info')),
        findsNothing,
      );

      // Tap bar for 2026-11-03 (net profit 15,298.97 -> ฿15,299)
      final barFinder = find.byKey(
        const ValueKey('profit-chart-bar-2026-11-03'),
      );
      expect(barFinder, findsOneWidget);
      await tester.ensureVisible(barFinder);
      await tester.tap(barFinder);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('profit-chart-selected-info')),
        findsOneWidget,
      );
      expect(
        find.textContaining('3 พ.ย. (อ. 3 พ.ย. 69) · กำไรสุทธิ ฿15,299'),
        findsOneWidget,
      );

      // Tap "ไปนับของเหลือ" -> navigates to /stock
      final goStockBtn = find.byKey(const ValueKey('dashboard-go-stock-btn'));
      await tester.ensureVisible(goStockBtn);
      await tester.tap(goStockBtn);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('stock-count-save-btn')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Reports: tap daily report row navigates to /bills with that date selected',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _buildFullRepo(fixedNow: fixedNow);
      await tester.pumpWidget(
        KepTohApp(repository: repo, now: fixedNow, initialLocation: '/reports'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('daily-report-table')), findsOneWidget);

      // Tap the pinned date cell for 2026-11-03
      final rowFinder = find.byKey(const ValueKey('report-row-2026-11-03'));
      expect(rowFinder, findsOneWidget);
      await tester.tap(rowFinder);
      await tester.pumpAndSettle();

      // Should now be on /bills with selectedDate == '2026-11-03'
      expect(find.byType(BillsPage), findsOneWidget);
      final billsContext = tester.element(find.byType(BillsPage));
      final billsState = billsContext.read<BillsCubit>().state;
      expect(billsState.selectedDate, '2026-11-03');
    },
  );

  testWidgets(
    'Cashier role cannot access /dashboard or /reports (redirected to /tables)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // st3 is cashier
      final repo = _buildFullRepo(fixedNow: fixedNow, sessionStaffId: 'st3');
      await tester.pumpWidget(
        KepTohApp(
          repository: repo,
          now: fixedNow,
          initialLocation: '/dashboard',
        ),
      );
      await tester.pumpAndSettle();

      // Redirected away from /dashboard to /tables
      expect(find.byKey(const ValueKey('dashboard-hero-card')), findsNothing);
      expect(find.byType(TablesPage), findsOneWidget);
    },
  );
}
