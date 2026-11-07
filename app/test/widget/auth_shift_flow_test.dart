import 'dart:io';

import 'package:app/app.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

MockPosRepository _buildTestRepo({bool closeInitialShift = true}) {
  final fixedNow = DateTime(2026, 11, 4, 12);
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
  final repo = MockPosRepository.fromJsonStrings(jsonByName, now: fixedNow);
  if (closeInitialShift) {
    repo.update((s) {
      closeShift(s, staffId: 'st3', counted: 544600, now: fixedNow);
    });
  }
  return repo;
}

void main() {
  group('F3 Widget Flow: Login -> Open Shift -> Role-based Access', () {
    testWidgets('cashier logs in with PIN, opens shift, sees 4 views, '
        'and redirects from restricted routes', (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _buildTestRepo();
      await tester.pumpWidget(
        KepTohApp(repository: repo, now: DateTime(2026, 11, 4, 12)),
      );
      await tester.pumpAndSettle();

      // Unauthenticated user is redirected to /login
      expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
      expect(find.byKey(const ValueKey('login-submit-btn')), findsNothing);

      // Select cashier เนส (st3, PIN 1111) from Dropdown
      await tester.tap(find.text('อัย'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เนส').last);
      await tester.pumpAndSettle();

      // Enter wrong PIN 9999 -> auto-validates on 4th digit and shows error
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('9'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('PIN ไม่ถูกต้อง ลองใหม่อีกครั้ง'), findsOneWidget);

      // Enter valid PIN 1111 -> auto-logs in on 4th digit & prompts OpenShift
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('1'));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // OpenShiftModal is shown because no shift was open
      expect(find.text('เปิดกะการขาย'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-shift-submit-btn')));
      await tester.pumpAndSettle();

      expect(find.text('เปิดกะการขาย'), findsNothing);
      expect(openShiftOf(repo.state), isNotNull);

      // Open Sidebar and check cashier role menu items (only 4 views)
      await tester.tap(find.byKey(const ValueKey('shell-menu-btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('drawer-nav-tables')), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-nav-bills')), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-nav-stock')), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-nav-shift')), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-nav-dashboard')), findsNothing);
      expect(find.byKey(const ValueKey('drawer-nav-reports')), findsNothing);
      expect(find.byKey(const ValueKey('drawer-nav-setup')), findsNothing);

      // Navigate to restricted route /reports as cashier -> redirects
      final shellCtx = tester.element(
        find.byKey(const ValueKey('shell-header')),
      );
      GoRouter.of(shellCtx).go('/reports');
      await tester.pumpAndSettle();
      expect(find.text('โต๊ะและการขาย'), findsWidgets);
    });

    testWidgets('owner logs in, sees all 7 views, and closes shift on /shift', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _buildTestRepo(closeInitialShift: false);
      await tester.pumpWidget(
        KepTohApp(repository: repo, now: DateTime(2026, 11, 4, 12)),
      );
      await tester.pumpAndSettle();

      // Default selected staff is st1 (คุณแอน, owner, PIN 1234)
      for (final d in ['1', '2', '3', '4']) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Open Sidebar -> owner sees all 7 views
      await tester.tap(find.byKey(const ValueKey('shell-menu-btn')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('drawer-nav-dashboard')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('drawer-nav-reports')), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-nav-setup')), findsOneWidget);

      // Navigate to /shift
      await tester.tap(find.byKey(const ValueKey('drawer-nav-shift')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('active-shift-card')), findsOneWidget);
      expect(find.text('฿5,446'), findsOneWidget);

      final closeBtnFinder = find.byKey(const ValueKey('close-shift-btn'));
      final closeXBefore = tester.getTopLeft(closeBtnFinder).dx;

      // Tap quick-fill expected cash button -> fills 5,446 without layout shift
      await tester.tap(find.byKey(const ValueKey('shift-fill-expected-btn')));
      await tester.pumpAndSettle();
      expect(find.text('5,446'), findsOneWidget);
      expect(tester.getTopLeft(closeBtnFinder).dx, equals(closeXBefore));

      // Clear and enter counted cash manually
      await tester.tap(find.byKey(const ValueKey('shift-clear-counted-btn')));
      await tester.pumpAndSettle();

      // Enter counted cash and close shift
      await tester.enterText(
        find.byKey(const ValueKey('shift-counted-input')),
        '5446',
      );
      await tester.pumpAndSettle();
      expect(find.text('ยอดตรง'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('close-shift-btn')));
      await tester.pumpAndSettle();
      expect(find.text('ปิดกะ?'), findsOneWidget);
      expect(find.text('เงินสดที่นับได้จริง'), findsOneWidget);

      await tester.tap(find.text('ปิดกะ').last);
      await tester.pumpAndSettle();

      expect(openShiftOf(repo.state), isNull);
      expect(find.text('ยังไม่เปิดกะ'), findsWidgets);

      // Quick preset float selection formats with comma (2,000)
      await tester.tap(find.byKey(const ValueKey('shift-float-preset-2000')));
      await tester.pumpAndSettle();
      expect(find.text('2,000'), findsOneWidget);
    });

    testWidgets(
      'portrait tablet (768x1024) and mobile (390x844) render compact ledger '
      'banner without full hero panel',
      (tester) async {
        addTearDown(tester.view.reset);
        for (final size in [const Size(768, 1024), const Size(390, 844)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final repo = _buildTestRepo();
          await tester.pumpWidget(
            KepTohApp(repository: repo, now: DateTime(2026, 11, 4, 12)),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('login-hero-panel')), findsNothing);
          expect(
            find.byKey(const ValueKey('login-compact-ledger-banner')),
            findsOneWidget,
          );
        }
      },
    );
  });
}
