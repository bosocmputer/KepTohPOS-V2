import 'package:app/app.dart';
import 'package:app/core/layout/app_shell.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppShell responsive layout & role permissions', () {
    testWidgets(
      'width >= 761 (1366x1024) renders 72px header (64px at <= 820h) '
      'and 365px drawer',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        var selectedView = 'tables';
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build(brightness: Brightness.light),
            home: StatefulBuilder(
              builder: (context, setState) => AppShell(
                activeViewId: selectedView,
                onNavigate: (id) => setState(() => selectedView = id),
                child: const Center(child: Text('Body Content')),
              ),
            ),
          ),
        );

        final headerBox = tester.getSize(
          find.byKey(const ValueKey('shell-header')),
        );
        expect(headerBox.height, AppDimensions.headerH);
        expect(headerBox.height, 72);

        // At 1024x768 (height <= 820), header is 64px
        tester.view.physicalSize = const Size(1024, 768);
        await tester.pumpAndSettle();
        final compactHeaderBox = tester.getSize(
          find.byKey(const ValueKey('shell-header')),
        );
        expect(compactHeaderBox.height, AppDimensions.headerCompactH);
        expect(compactHeaderBox.height, 64);

        tester.view.physicalSize = const Size(1366, 1024);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('shell-bottom-nav')), findsNothing);
        expect(find.byKey(const ValueKey('drawer-scrim')), findsNothing);

        // Open slide-over sidebar (365px + dark backdrop)
        await tester.tap(find.byKey(const ValueKey('shell-menu-btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('drawer-scrim')), findsOneWidget);
        final panelBox = tester.getSize(find.byType(NavPanel));
        expect(panelBox.width, AppDimensions.drawerW);

        // Navigate via drawer item
        await tester.tap(find.byKey(const ValueKey('drawer-nav-bills')));
        await tester.pumpAndSettle();
        expect(selectedView, 'bills');
        expect(find.byKey(const ValueKey('drawer-scrim')), findsNothing);
      },
    );

    testWidgets(
      'width <= 760 (390x844) renders bottom nav (4 items + เพิ่มเติม)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build(brightness: Brightness.light),
            home: AppShell(
              activeViewId: 'tables',
              onNavigate: (_) {},
              child: const SizedBox.shrink(),
            ),
          ),
        );

        expect(find.byKey(const ValueKey('shell-bottom-nav')), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom-nav-tables')), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom-nav-bills')), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom-nav-stock')), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom-nav-shift')), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom-nav-more')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('bottom-nav-more')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('drawer-scrim')), findsOneWidget);
      },
    );

    testWidgets('cashier role sees only 4 views and is blocked from reports', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(brightness: Brightness.light),
          home: AppShell(
            activeViewId: 'reports',
            staffRole: 'cashier',
            staffName: 'น้องมายด์',
            onNavigate: (_) {},
            child: const Text('Report Secret'),
          ),
        ),
      );

      expect(find.text('ไม่มีสิทธิ์เข้าหน้านี้'), findsOneWidget);
      expect(find.text('Report Secret'), findsNothing);
      expect(find.byKey(const ValueKey('bottom-nav-more')), findsNothing);
    });

    testWidgets('GoRouter navigates across VIEWS routes via AppShell drawer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const KepTohApp());
      await tester.pumpAndSettle();

      expect(find.text('โต๊ะและการขาย'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('shell-menu-btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('drawer-nav-reports')));
      await tester.pumpAndSettle();
      expect(find.text('รายงานรายวัน'), findsWidgets);

      // Open Sidebar from /reports -> push /dev/components -> tap back -> returns to /reports
      await tester.tap(find.byKey(const ValueKey('shell-menu-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawer-nav-dev-components')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dev-components-back-btn')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('dev-components-back-btn')));
      await tester.pumpAndSettle();

      expect(find.text('รายงานรายวัน'), findsWidgets);
    });
  });
}
