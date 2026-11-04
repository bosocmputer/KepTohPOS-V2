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

Widget _buildTablesGolden(MockPosRepository repo, DateTime now) =>
    RepositoryProvider<PosRepository>.value(
      value: repo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
          BlocProvider<AuthCubit>(create: (_) => AuthCubit(repo)),
          BlocProvider<ShiftBloc>(create: (_) => ShiftBloc(repo)),
          BlocProvider<TablesCubit>(create: (_) => TablesCubit(repo, now: now)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(brightness: Brightness.light),
          home: ShellPlaceholderPage(viewSpec: kAppViews.first),
        ),
      ),
    );

Widget _buildSaleGolden(
  MockPosRepository repo,
  DateTime now, {
  String tableId = 't2',
  SaleBloc? saleBloc,
}) => RepositoryProvider<PosRepository>.value(
  value: repo,
  child: MultiBlocProvider(
    providers: [
      BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
      BlocProvider<AuthCubit>(create: (_) => AuthCubit(repo)),
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
    testWidgets('TablesPage at 1366x1024', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _createSeededRepo(fixedNow);
      await tester.pumpWidget(_buildTablesGolden(repo, fixedNow));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('tables_1366x1024.png'),
      );
    });

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

    testWidgets('SalePage at 1366x1024', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _createSeededRepo(fixedNow);
      final saleBloc = SaleBloc(repo, initialTableId: 't2', now: fixedNow)
        ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 2));
      addTearDown(saleBloc.close);

      await tester.pumpWidget(
        _buildSaleGolden(repo, fixedNow, saleBloc: saleBloc),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('sale_1366x1024.png'),
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

    testWidgets('Payment Cash at 1366x1024', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
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
        _buildSaleGolden(repo, fixedNow, saleBloc: saleBloc),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('payment_cash_1366x1024.png'),
      );
    });

    testWidgets('Payment PromptPay at 1366x1024', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _createSeededRepo(fixedNow);
      final saleBloc = SaleBloc(repo, initialTableId: 't2', now: fixedNow)
        ..add(const SaleCategorySelected('เครื่องดื่ม'))
        ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 2))
        ..add(const SalePaymentStepChanged('pay'))
        ..add(const SalePaymentMethodSelected('pm2'));
      addTearDown(saleBloc.close);

      await tester.pumpWidget(
        _buildSaleGolden(repo, fixedNow, saleBloc: saleBloc),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('payment_promptpay_1366x1024.png'),
      );
    });

    testWidgets('Receipt Modal at 1366x1024', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _createSeededRepo(fixedNow);
      final staff = repo.state.staff.first;
      final saleBloc = SaleBloc(repo, initialTableId: 't2', now: fixedNow)
        ..add(const SalePaymentStepChanged('pay'))
        ..add(const SalePaymentMethodSelected('pm1'))
        ..add(const SaleCashReceivedChanged('1000'))
        ..add(
          SalePaymentSubmitted(staff: staff, billId: 'b_golden', now: fixedNow),
        );
      addTearDown(saleBloc.close);

      await tester.pumpWidget(
        _buildSaleGolden(repo, fixedNow, saleBloc: saleBloc),
      );
      await tester.pumpAndSettle();
      await _precacheImages(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('receipt_1366x1024.png'),
      );
    });
  });
}
