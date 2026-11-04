import 'package:app/core/router/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/roles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _buildGoldenShell({bool drawerOpen = false}) => BlocProvider(
  create: (_) => ThemeCubit(),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(brightness: Brightness.light),
    home: ShellPlaceholderPage(
      viewSpec: kAppViews.first,
      initialDrawerOpen: drawerOpen,
    ),
  ),
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppShell Golden Tests (1366x1024, 820x1180, 390x844)', () {
    testWidgets(
      'AppShell at 1366x1024 (desktop/landscape tablet with drawer)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1366, 1024));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_buildGoldenShell(drawerOpen: true));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('app_shell_1366x1024.png'),
        );
      },
    );

    testWidgets('AppShell at 820x1180 (portrait tablet >= 761)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(820, 1180));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildGoldenShell());
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('app_shell_820x1180.png'),
      );
    });

    testWidgets('AppShell at 390x844 (mobile <= 760 with bottom nav)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildGoldenShell());
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('app_shell_390x844.png'),
      );
    });
  });
}
