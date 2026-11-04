import 'dart:io';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/router/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:app/features/stock/presentation/bloc/stock_count_bloc.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:app/features/tables/presentation/cubit/tables_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

MockPosRepository _createSeededStockRepo(DateTime now) {
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

Widget _buildStockGolden(
  MockPosRepository repo,
  StockCubit stockCubit,
  StockCountBloc countBloc,
  DateTime now, {
  EdgeInsets safePad = EdgeInsets.zero,
}) {
  final stockView = kAppViews.firstWhere((v) => v.id == 'stock');
  return RepositoryProvider<PosRepository>.value(
    value: repo,
    child: MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
        BlocProvider<AuthCubit>(create: (_) => AuthCubit(repo)),
        BlocProvider<ShiftBloc>(create: (_) => ShiftBloc(repo)),
        BlocProvider<TablesCubit>(create: (_) => TablesCubit(repo, now: now)),
        BlocProvider<StockCubit>.value(value: stockCubit),
        BlocProvider<StockCountBloc>.value(value: countBloc),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(brightness: Brightness.light),
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
        home: ShellPlaceholderPage(viewSpec: stockView),
      ),
    ),
  );
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 18);

  group(
    'F6 Stock Goldens (Count, Purchase, Expense, Balance, Modal, Filter)',
    () {
      for (final (label, size, safePad) in _kSpecs) {
        testWidgets('stock_count_$label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final repo = _createSeededStockRepo(fixedNow);
          final cubit = StockCubit(repo, now: fixedNow);
          final bloc = StockCountBloc(repository: repo, now: fixedNow)
            ..add(const StockCountValueChanged('8.5'))
            ..add(const StockCountNextPressed())
            ..add(const StockCountValueChanged('4.2'));
          addTearDown(cubit.close);
          addTearDown(bloc.close);

          await tester.pumpWidget(
            _buildStockGolden(repo, cubit, bloc, fixedNow, safePad: safePad),
          );
          await _precacheImages(tester);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('stock_count_$label.png'),
          );
        });

        testWidgets('stock_purchase_$label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final repo = _createSeededStockRepo(fixedNow);
          final cubit = StockCubit(repo, now: fixedNow, initialTab: 'purchase');
          final bloc = StockCountBloc(repository: repo, now: fixedNow);
          addTearDown(cubit.close);
          addTearDown(bloc.close);

          await tester.pumpWidget(
            _buildStockGolden(repo, cubit, bloc, fixedNow, safePad: safePad),
          );
          await _precacheImages(tester);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('stock_purchase_$label.png'),
          );
        });

        testWidgets('stock_purchase_modal_$label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final repo = _createSeededStockRepo(fixedNow);
          final cubit = StockCubit(repo, now: fixedNow, initialTab: 'purchase');
          final bloc = StockCountBloc(repository: repo, now: fixedNow);
          addTearDown(cubit.close);
          addTearDown(bloc.close);

          await tester.pumpWidget(
            _buildStockGolden(repo, cubit, bloc, fixedNow, safePad: safePad),
          );
          await _precacheImages(tester);

          await tester.tap(find.byKey(const ValueKey('purchase-copy-sup-s1')));
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('stock_purchase_modal_$label.png'),
          );
        });

        testWidgets('stock_expense_$label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final repo = _createSeededStockRepo(fixedNow);
          final cubit = StockCubit(repo, now: fixedNow, initialTab: 'expense');
          final bloc = StockCountBloc(repository: repo, now: fixedNow);
          addTearDown(cubit.close);
          addTearDown(bloc.close);

          await tester.pumpWidget(
            _buildStockGolden(repo, cubit, bloc, fixedNow, safePad: safePad),
          );
          await _precacheImages(tester);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('stock_expense_$label.png'),
          );
        });

        testWidgets('stock_balance_list_$label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final repo = _createSeededStockRepo(fixedNow);
          final cubit = StockCubit(repo, now: fixedNow, initialTab: 'balance');
          final bloc = StockCountBloc(repository: repo, now: fixedNow);
          addTearDown(cubit.close);
          addTearDown(bloc.close);

          await tester.pumpWidget(
            _buildStockGolden(repo, cubit, bloc, fixedNow, safePad: safePad),
          );
          await _precacheImages(tester);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('stock_balance_list_$label.png'),
          );
        });

        testWidgets('stock_balance_grid_$label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final repo = _createSeededStockRepo(fixedNow);
          final cubit = StockCubit(repo, now: fixedNow, initialTab: 'balance')
            ..setBalanceViewMode('grid');
          final bloc = StockCountBloc(repository: repo, now: fixedNow);
          addTearDown(cubit.close);
          addTearDown(bloc.close);

          await tester.pumpWidget(
            _buildStockGolden(repo, cubit, bloc, fixedNow, safePad: safePad),
          );
          await _precacheImages(tester);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('stock_balance_grid_$label.png'),
          );
        });

        testWidgets('stock_filter_drawer_$label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final repo = _createSeededStockRepo(fixedNow);
          final cubit = StockCubit(repo, now: fixedNow, initialTab: 'balance')
            ..toggleLocationFilter('fridge')
            ..setStatusFilter('low')
            ..setFilterDrawerOpen(open: true);
          final bloc = StockCountBloc(repository: repo, now: fixedNow);
          addTearDown(cubit.close);
          addTearDown(bloc.close);

          await tester.pumpWidget(
            _buildStockGolden(repo, cubit, bloc, fixedNow, safePad: safePad),
          );
          await _precacheImages(tester);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('stock_filter_drawer_$label.png'),
          );
        });
      }
    },
  );
}
