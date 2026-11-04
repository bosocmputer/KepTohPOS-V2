import 'dart:io';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/router/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:app/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:app/features/tables/presentation/cubit/tables_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

MockPosRepository _createSeededRepo(DateTime now) {
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
    now: now,
    sessionStaffId: 'st1',
  );
}

Future<void> _precacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final el in find.byType(Image).evaluate()) {
      final img = el.widget as Image;
      await precacheImage(img.image, el);
    }
  });
  await tester.pumpAndSettle();
}

const _kSpecs = <(String, Size, EdgeInsets)>[
  ('1024x768', Size(1024, 768), EdgeInsets.only(top: 24)),
  ('1366x1024', Size(1366, 1024), EdgeInsets.zero),
];

Widget _buildF7Golden({
  required MockPosRepository repo,
  required String viewId,
  required DateTime now,
  DashboardCubit? dashboardCubit,
  ReportsCubit? reportsCubit,
  EdgeInsets safePad = EdgeInsets.zero,
  Brightness brightness = Brightness.light,
}) {
  final viewSpec = kAppViews.firstWhere((v) => v.id == viewId);
  return RepositoryProvider<PosRepository>.value(
    value: repo,
    child: MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
        BlocProvider<AuthCubit>(create: (_) => AuthCubit(repo, now: now)),
        BlocProvider<ShiftBloc>(create: (_) => ShiftBloc(repo)),
        BlocProvider<TablesCubit>(create: (_) => TablesCubit(repo, now: now)),
        if (dashboardCubit != null)
          BlocProvider<DashboardCubit>.value(value: dashboardCubit),
        if (reportsCubit != null)
          BlocProvider<ReportsCubit>.value(value: reportsCubit),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(brightness: brightness),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return LayoutBuilder(
            builder: (context, constraints) => MediaQuery(
              data: mq.copyWith(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                padding: safePad,
                viewPadding: safePad,
              ),
              child: child!,
            ),
          );
        },
        home: ShellPlaceholderPage(viewSpec: viewSpec),
      ),
    ),
  );
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 18);

  group('F7 Dashboard & Reports Goldens', () {
    for (final (label, size, safePad) in _kSpecs) {
      testWidgets('dashboard_30d_$label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final repo = _createSeededRepo(fixedNow);
        final cubit = DashboardCubit(repo, now: fixedNow);
        addTearDown(cubit.close);

        await tester.pumpWidget(
          _buildF7Golden(
            repo: repo,
            viewId: 'dashboard',
            now: fixedNow,
            dashboardCubit: cubit,
            safePad: safePad,
          ),
        );
        await _precacheImages(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('dashboard_30d_$label.png'),
        );
      });

      testWidgets('reports_$label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final repo = _createSeededRepo(fixedNow);
        final cubit = ReportsCubit(repo, now: fixedNow);
        addTearDown(cubit.close);

        await tester.pumpWidget(
          _buildF7Golden(
            repo: repo,
            viewId: 'reports',
            now: fixedNow,
            reportsCubit: cubit,
            safePad: safePad,
          ),
        );
        await _precacheImages(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('reports_$label.png'),
        );
      });
    }

    testWidgets('dashboard_30d_dark_1024x768', (tester) async {
      const size = Size(1024, 768);
      const safePad = EdgeInsets.only(top: 24);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _createSeededRepo(fixedNow);
      final cubit = DashboardCubit(repo, now: fixedNow);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        _buildF7Golden(
          repo: repo,
          viewId: 'dashboard',
          now: fixedNow,
          dashboardCubit: cubit,
          safePad: safePad,
          brightness: Brightness.dark,
        ),
      );
      await _precacheImages(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('dashboard_30d_dark_1024x768.png'),
      );
    });
  });
}
