import 'dart:convert';
import 'dart:io';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:app/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

PosState _loadSeededState(DateTime fixedNow) {
  Map<String, dynamic> readObj(String name) =>
      jsonDecode(File('assets/mock/$name.json').readAsStringSync())
          as Map<String, dynamic>;
  List<Map<String, dynamic>> readList(String name) => (jsonDecode(
    File('assets/mock/$name.json').readAsStringSync(),
  ) as List<dynamic>).cast<Map<String, dynamic>>();

  return seed(
    shop: ShopConfig.fromJson(readObj('shop')),
    packages: readList('packages').map(PackageItem.fromJson).toList(),
    addons: readList('addons').map(AddonItem.fromJson).toList(),
    suppliers: readList('suppliers').map(SupplierItem.fromJson).toList(),
    ingredients: readList('ingredients').map(IngredientItem.fromJson).toList(),
    tables: readList('tables').map(DiningTable.fromJson).toList(),
    staff: readList('staff').map(StaffMember.fromJson).toList(),
    payments: readList('payments').map(PaymentMethod.fromJson).toList(),
    expenseTypes: readList('expense_types').map(ExpenseType.fromJson).toList(),
    fixedCosts: readList('fixed_costs').map(FixedCostItem.fromJson).toList(),
    now: fixedNow,
  );
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 12);

  group('DashboardCubit', () {
    blocTest<DashboardCubit, DashboardState>(
      'changing range updates period summary numbers accurately',
      build: () => DashboardCubit(
        MockPosRepository(initialState: _loadSeededState(fixedNow)),
        now: fixedNow,
      ),
      act: (cubit) => cubit
        ..setRange('7')
        ..setRange('month')
        ..setRange('today'),
      verify: (cubit) {
        expect(cubit.state.range, 'today');
        expect(r2(cubit.state.summary.net), 8830);
        expect(cubit.state.summary.closedDays, isEmpty);
      },
      expect: () => [
        isA<DashboardState>()
            .having((s) => s.range, 'range', '7')
            .having((s) => r2(s.summary.net), 'net', 189100)
            .having((s) => r2(s.summary.profit), 'profit', 109272.94)
            .having((s) => r2(s.summary.netProfit), 'netProfit', 98612.94),
        isA<DashboardState>()
            .having((s) => s.range, 'range', 'month')
            .having((s) => r2(s.summary.net), 'net', 90379)
            .having((s) => r2(s.summary.profit), 'profit', 49294.34)
            .having((s) => r2(s.summary.netProfit), 'netProfit', 43964.34),
        isA<DashboardState>()
            .having((s) => s.range, 'range', 'today')
            .having((s) => r2(s.summary.net), 'net', 8830)
            .having((s) => s.summary.closedDays.length, 'closedDays', 0),
      ],
    );

    blocTest<DashboardCubit, DashboardState>(
      'showNetProfit = false switches dashboard metric to gross profit',
      build: () {
        final repo = MockPosRepository(
          initialState: _loadSeededState(fixedNow),
        );
        return DashboardCubit(repo, now: fixedNow);
      },
      act: (cubit) {
        cubit.selectBarDate('2026-11-03');
      },
      verify: (cubit) {
        final barDay = cubit.state.selectedBarDay!;
        expect(barDay.date, '2026-11-03');
        expect(r2(barDay.profit!), 16935.64);
        expect(r2(barDay.netProfit!), 15298.97);
      },
    );

    test(
      'repository update with showNetProfit = false emits gross mode',
      () async {
        final repo = MockPosRepository(
          initialState: _loadSeededState(fixedNow),
        );
        final cubit = DashboardCubit(repo, now: fixedNow);
        addTearDown(cubit.close);

        expect(cubit.state.summary.showNetProfit, isTrue);
        expect(cubit.state.summary.fieldName, 'กำไรสุทธิ');

        repo.update((s) {
          s.shop = s.shop.copyWith(showNetProfit: false);
        });
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.summary.showNetProfit, isFalse);
        expect(cubit.state.summary.fieldName, 'กำไรขั้นต้น');
        final last = cubit.state.summary.lastClosedDay!;
        expect(r2(cubit.state.summary.dayMetric(last)!), 16935.64);
      },
    );
  });

  group('ReportsCubit & Role Permissions', () {
    blocTest<ReportsCubit, ReportsState>(
      'changing month updates monthly report totals accurately',
      build: () => ReportsCubit(
        MockPosRepository(initialState: _loadSeededState(fixedNow)),
        now: fixedNow,
      ),
      act: (cubit) => cubit.setMonth('2026-10'),
      expect: () => [
        isA<ReportsState>()
            .having((s) => s.selectedMonth, 'selectedMonth', '2026-10')
            .having((s) => s.report.days.length, 'days', 27)
            .having((s) => r2(s.report.totalNet), 'totalNet', 777627)
            .having((s) => r2(s.report.closedProfit), 'closedProfit', 471749.35)
            .having(
              (s) => r2(s.report.closedNetProfit),
              'closedNetProfit',
              423779.35,
            ),
      ],
    );

    test(
      'cashier is blocked from dashboard & reports while manager/owner access',
      () {
        expect(canAccessViewId('cashier', 'dashboard'), isFalse);
        expect(canAccessViewId('cashier', 'reports'), isFalse);
        expect(canAccessViewId('manager', 'dashboard'), isTrue);
        expect(canAccessViewId('manager', 'reports'), isTrue);
        expect(canAccessViewId('owner', 'dashboard'), isTrue);
        expect(canAccessViewId('owner', 'reports'), isTrue);
      },
    );
  });
}
