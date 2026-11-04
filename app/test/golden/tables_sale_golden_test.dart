import 'dart:io';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/router/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
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
  ('1180x820', Size(1180, 820), EdgeInsets.only(top: 24, bottom: 20)),
  ('1366x1024', Size(1366, 1024), EdgeInsets.zero),
];

Widget _buildTablesGolden(
  MockPosRepository repo,
  DateTime now, {
  EdgeInsets safePad = EdgeInsets.zero,
}) => RepositoryProvider<PosRepository>.value(
  value: repo,
  child: MultiBlocProvider(
    providers: [
      BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
      BlocProvider<AuthCubit>(create: (_) => AuthCubit(repo, now: now)),
      BlocProvider<ShiftBloc>(create: (_) => ShiftBloc(repo)),
      BlocProvider<TablesCubit>(create: (_) => TablesCubit(repo, now: now)),
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
      home: ShellPlaceholderPage(viewSpec: kAppViews.first),
    ),
  ),
);

Widget _buildSaleGolden(
  MockPosRepository repo,
  DateTime now, {
  String tableId = 't2',
  SaleBloc? saleBloc,
  EdgeInsets safePad = EdgeInsets.zero,
}) => RepositoryProvider<PosRepository>.value(
  value: repo,
  child: MultiBlocProvider(
    providers: [
      BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
      BlocProvider<AuthCubit>(create: (_) => AuthCubit(repo, now: now)),
      BlocProvider<ShiftBloc>(create: (_) => ShiftBloc(repo)),
      BlocProvider<TablesCubit>(create: (_) => TablesCubit(repo, now: now)),
      if (saleBloc != null)
        BlocProvider<SaleBloc>.value(value: saleBloc)
      else
        BlocProvider<SaleBloc>(
          create: (_) => SaleBloc(repo, initialTableId: tableId, now: now),
        ),
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
      home: ShellPlaceholderPage(
        viewSpec: kAppViews.first,
        saleTableId: tableId,
      ),
    ),
  ),
);

void main() {
  final fixedNow = DateTime(2026, 11, 4, 19, 30);

  group('Tables, Sale & Payment Golden Tests', () {
    for (final (name, size, pad) in _kSpecs) {
      testWidgets('TablesPage at $name', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = _createSeededRepo(fixedNow);
        await tester.pumpWidget(
          _buildTablesGolden(repo, fixedNow, safePad: pad),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('tables_$name.png'),
        );
      });

      testWidgets('TablesPage with dropdown open at $name', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = _createSeededRepo(fixedNow);
        await tester.pumpWidget(
          _buildTablesGolden(repo, fixedNow, safePad: pad),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('tables-zone-dropdown')));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('tables_dropdown_$name.png'),
        );
      });

      testWidgets('SalePage at $name', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = _createSeededRepo(fixedNow);
        final saleBloc = SaleBloc(repo, initialTableId: 't2', now: fixedNow)
          ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 2));
        addTearDown(saleBloc.close);

        await tester.pumpWidget(
          _buildSaleGolden(repo, fixedNow, saleBloc: saleBloc, safePad: pad),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('sale_$name.png'),
        );
      });

      testWidgets('Payment Cash at $name', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = _createSeededRepo(fixedNow);
        final saleBloc = SaleBloc(repo, initialTableId: 't2', now: fixedNow)
          ..add(const SaleCategorySelected('เครื่องดื่ม'))
          ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 2))
          ..add(const SalePaymentStepChanged('pay'))
          ..add(const SalePaymentMethodSelected('pm1'))
          ..add(const SaleCashReceivedChanged('1000'));
        addTearDown(saleBloc.close);

        await tester.pumpWidget(
          _buildSaleGolden(repo, fixedNow, saleBloc: saleBloc, safePad: pad),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('payment_cash_$name.png'),
        );
      });

      testWidgets('Payment PromptPay at $name', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = _createSeededRepo(fixedNow);
        final saleBloc = SaleBloc(repo, initialTableId: 't2', now: fixedNow)
          ..add(const SaleCategorySelected('เครื่องดื่ม'))
          ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 2))
          ..add(const SalePaymentStepChanged('pay'))
          ..add(const SalePaymentMethodSelected('pm2'));
        addTearDown(saleBloc.close);

        await tester.pumpWidget(
          _buildSaleGolden(repo, fixedNow, saleBloc: saleBloc, safePad: pad),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('payment_promptpay_$name.png'),
        );
      });

      testWidgets('Receipt Modal at $name', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = _createSeededRepo(fixedNow);
        final staff = repo.state.staff.first;
        final saleBloc = SaleBloc(repo, initialTableId: 't2', now: fixedNow)
          ..add(const SalePaymentStepChanged('pay'))
          ..add(const SalePaymentMethodSelected('pm1'))
          ..add(const SaleCashReceivedChanged('1000'))
          ..add(
            SalePaymentSubmitted(
              staff: staff,
              billId: 'b_golden',
              now: fixedNow,
            ),
          );
        addTearDown(saleBloc.close);

        await tester.pumpWidget(
          _buildSaleGolden(repo, fixedNow, saleBloc: saleBloc, safePad: pad),
        );
        await tester.pumpAndSettle();
        await _precacheImages(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('receipt_$name.png'),
        );
      });
    }

    testWidgets('TablesPage at 390x844', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _createSeededRepo(fixedNow);
      await tester.pumpWidget(_buildTablesGolden(repo, fixedNow));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('tables_390x844.png'),
      );
    });

    testWidgets('SalePage at 390x844', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _createSeededRepo(fixedNow);
      await tester.pumpWidget(_buildSaleGolden(repo, fixedNow));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('sale_390x844.png'),
      );
    });
  });
}
