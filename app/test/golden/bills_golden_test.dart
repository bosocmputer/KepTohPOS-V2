import 'dart:io';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/router/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:app/features/tables/presentation/cubit/tables_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

MockPosRepository _createSeededBillsRepo(DateTime now) {
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
  )..update((s) {
    final owner = s.staff.firstWhere((st) => st.role == 'owner');
    final todayBills = s.sales.where((b) => b.date == dkey(now)).toList()
      ..sort((x, y) => y.at.compareTo(x.at));
    if (todayBills.length > 1) {
      voidBill(
        s,
        billId: todayBills[1].id,
        me: owner,
        reason: 'คีย์จำนวนคนผิด',
        now: now,
      );
    }
  });
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

Widget _buildBillsGolden(
  MockPosRepository repo,
  BillsCubit billsCubit,
  DateTime now, {
  EdgeInsets safePad = EdgeInsets.zero,
}) {
  final billsView = kAppViews.firstWhere((v) => v.id == 'bills');
  return RepositoryProvider<PosRepository>.value(
    value: repo,
    child: MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
        BlocProvider<AuthCubit>(create: (_) => AuthCubit(repo, now: now)),
        BlocProvider<ShiftBloc>(create: (_) => ShiftBloc(repo)),
        BlocProvider<TablesCubit>(create: (_) => TablesCubit(repo, now: now)),
        BlocProvider<BillsCubit>.value(value: billsCubit),
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
        home: ShellPlaceholderPage(viewSpec: billsView),
      ),
    ),
  );
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 18);

  group('F5 Bills & Voided Receipt Goldens', () {
    for (final (label, size, safePad) in _kSpecs) {
      testWidgets('bills_$label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final repo = _createSeededBillsRepo(fixedNow);
        final cubit = BillsCubit(repo, now: fixedNow);
        addTearDown(cubit.close);

        await tester.pumpWidget(
          _buildBillsGolden(repo, cubit, fixedNow, safePad: safePad),
        );
        await _precacheImages(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('bills_$label.png'),
        );
      });

      testWidgets('bills_filter_$label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final repo = _createSeededBillsRepo(fixedNow);
        final cubit = BillsCubit(repo, now: fixedNow)
          ..toggleMethodFilter('pm1')
          ..setFilterDrawerOpen(open: true);
        addTearDown(cubit.close);

        await tester.pumpWidget(
          _buildBillsGolden(repo, cubit, fixedNow, safePad: safePad),
        );
        await _precacheImages(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('bills_filter_$label.png'),
        );
      });

      testWidgets('bills_void_receipt_$label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final repo = _createSeededBillsRepo(fixedNow);
        final cubit = BillsCubit(repo, now: fixedNow);
        addTearDown(cubit.close);
        final voidedBill = cubit.state.dayBills.firstWhere((b) => b.voided);
        cubit.selectBill(voidedBill.id);

        await tester.pumpWidget(
          _buildBillsGolden(repo, cubit, fixedNow, safePad: safePad),
        );
        await _precacheImages(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('bills_void_receipt_$label.png'),
        );
      });
    }
  });
}
