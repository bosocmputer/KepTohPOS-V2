import 'dart:io';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/bloc/stock_count_bloc.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

PosRepository _buildFullStockRepo(DateTime fixedNow) {
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
  return MockPosRepository.fromJsonStrings(jsonByName, now: fixedNow);
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 12);

  group('StockCountBloc', () {
    blocTest<StockCountBloc, StockCountState>(
      'steps through items with StockCountNextPressed, keeps activeId while '
      'typing, allows decimal on กก., and strips decimal on discrete units',
      build: () => StockCountBloc(
        repository: _buildFullStockRepo(fixedNow),
        now: fixedNow,
      ),
      act: (bloc) {
        bloc
          ..add(const StockCountValueChanged('10.2')) // i1 (กก.)
          ..add(const StockCountNextPressed()) // -> i2
          ..add(const StockCountItemSelected('i10')) // i10 (แพ็ค, discrete)
          ..add(const StockCountValueChanged('8.5')); // '.' stripped -> '85'
      },
      expect: () => <Matcher>[
        isA<StockCountState>()
            .having((s) => s.currentIngredientId, 'active i1', 'i1')
            .having((s) => s.currentValue, 'i1 value', '10.2')
            .having((s) => s.doneDueCount, 'doneDueCount', 1)
            .having((s) => s.canSave, 'canSave', isFalse),
        isA<StockCountState>().having(
          (s) => s.currentIngredientId,
          'advanced to i2',
          'i2',
        ),
        isA<StockCountState>().having(
          (s) => s.currentIngredientId,
          'selected i10',
          'i10',
        ),
        isA<StockCountState>()
            .having((s) => s.currentIngredientId, 'still i10', 'i10')
            .having((s) => s.currentValue, 'stripped dot', '85'),
      ],
    );

    test('canSave becomes true only when all 11 due items are counted, '
        'StockCountSaved rounds and closes the day, and only manager/owner can '
        'reopen', () async {
      final repo = _buildFullStockRepo(fixedNow);
      final bloc = StockCountBloc(repository: repo, now: fixedNow);
      addTearDown(bloc.close);

      expect(bloc.state.dueIngredients.length, 11);
      expect(bloc.state.canSave, isFalse);

      // Count first 10 due items -> still cannot save
      for (var i = 0; i < 10; i++) {
        bloc
          ..add(const StockCountValueChanged('5.46'))
          ..add(const StockCountNextPressed());
      }
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.doneDueCount, 10);
      expect(bloc.state.canSave, isFalse);

      // Count the 11th due item (i12 = ไข่ไก่, ฟอง)
      bloc.add(const StockCountValueChanged('40'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.doneDueCount, 11);
      expect(bloc.state.canSave, isTrue);

      // Save and close day
      bloc.add(const StockCountSaved());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isClosed, isTrue);
      expect(repo.state.counts['2026-11-04']!['i1'], 5.5); // rounded 1 dec
      expect(repo.state.counts['2026-11-04']!['i12'], 40);

      final cashier = repo.state.staff.firstWhere((s) => s.role == 'cashier');
      final manager = repo.state.staff.firstWhere((s) => s.role == 'manager');

      // Cashier cannot reopen
      bloc.add(StockCountDayReopened(staff: cashier));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isClosed, isTrue);

      // Manager can reopen
      bloc.add(StockCountDayReopened(staff: manager));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isClosed, isFalse);
    });
  });

  group('StockCubit permissions & filters (Rule 4)', () {
    test('cashier can add purchases and daily expenses, but only manager/owner '
        'can edit or delete purchases and expenses', () {
      final repo = _buildFullStockRepo(fixedNow);
      final cubit = StockCubit(repo, now: fixedNow);
      addTearDown(cubit.close);

      final cashier = repo.state.staff.firstWhere((s) => s.role == 'cashier');
      final owner = repo.state.staff.firstWhere((s) => s.role == 'owner');

      // Cashier adds a purchase on 2026-11-04
      final addedPur = cubit.submitPurchase(
        date: '2026-11-04',
        supplierId: 's1',
        lines: const <PurchaseLine>[
          PurchaseLine(ingId: 'i1', qty: 5, total: 950),
        ],
        staff: cashier,
        note: 'รับช่วงเช้า',
      );
      expect(addedPur, isTrue);
      final purId = cubit.state.dayPurchases.last.id;

      // Cashier cannot edit or delete that purchase
      expect(
        cubit.submitPurchase(
          date: '2026-11-04',
          supplierId: 's1',
          lines: const <PurchaseLine>[
            PurchaseLine(ingId: 'i1', qty: 8, total: 1500),
          ],
          staff: cashier,
          editId: purId,
        ),
        isFalse,
      );
      expect(cubit.removePurchase(purchaseId: purId, staff: cashier), isFalse);

      // Owner can edit and delete that purchase
      expect(
        cubit.submitPurchase(
          date: '2026-11-04',
          supplierId: 's1',
          lines: const <PurchaseLine>[
            PurchaseLine(ingId: 'i1', qty: 8, total: 1500),
          ],
          staff: owner,
          editId: purId,
        ),
        isTrue,
      );
      expect(cubit.removePurchase(purchaseId: purId, staff: owner), isTrue);

      // Cashier adds a daily expense on 2026-11-04
      final addedExp = cubit.submitExpenses(
        date: '2026-11-04',
        lines: const <ExpenseDraftLine>[
          ExpenseDraftLine(typeId: 'et1', amount: 250, note: 'น้ำแข็ง'),
        ],
        staff: cashier,
      );
      expect(addedExp, isTrue);
      final expId = cubit.state.dayExpenses.last.id;

      // Cashier cannot edit or delete daily expense
      expect(
        cubit.submitExpenses(
          date: '2026-11-04',
          lines: const <ExpenseDraftLine>[
            ExpenseDraftLine(typeId: 'et1', amount: 300, note: 'แก้ยอด'),
          ],
          staff: cashier,
          editId: expId,
        ),
        isFalse,
      );
      expect(cubit.removeExpense(expenseId: expId, staff: cashier), isFalse);

      // Owner can edit and delete daily expense
      expect(
        cubit.submitExpenses(
          date: '2026-11-04',
          lines: const <ExpenseDraftLine>[
            ExpenseDraftLine(typeId: 'et1', amount: 300, note: 'แก้ยอด'),
          ],
          staff: owner,
          editId: expId,
        ),
        isTrue,
      );
      expect(
        cubit.state.dayExpenses.firstWhere((e) => e.id == expId).amount,
        300,
      );
      expect(cubit.removeExpense(expenseId: expId, staff: owner), isTrue);
    });

    blocTest<StockCubit, StockState>(
      'filters balance rows by location, StockStatus, and searchQuery',
      build: () => StockCubit(_buildFullStockRepo(fixedNow), now: fixedNow),
      act: (cubit) {
        cubit
          ..toggleLocationFilter('freezer') // i6, i7, i8 (3 items)
          ..setSearchQuery('กุ้ง') // i6 only
          ..clearFilters()
          ..setSearchQuery('');
      },
      expect: () => <Matcher>[
        isA<StockState>()
            .having((s) => s.filteredBalanceRows.length, 'freezer count', 3)
            .having((s) => s.activeFilterCount, 'activeFilterCount', 1),
        isA<StockState>()
            .having((s) => s.filteredBalanceRows.length, 'search กุ้ง', 1)
            .having((s) => s.filteredBalanceRows.first.ing.id, 'id', 'i6'),
        isA<StockState>().having(
          (s) => s.activeFilterCount,
          'activeFilterCount',
          0,
        ),
        isA<StockState>().having(
          (s) => s.filteredBalanceRows.length,
          'all 15 items',
          15,
        ),
      ],
    );
  });
}
