import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

PosRepository _buildSeededBillsRepo(DateTime fixedNow) {
  return MockPosRepository.createFallback(now: fixedNow)..update((s) {
    final owner = s.staff.firstWhere((st) => st.role == 'owner');
    final cashier = s.staff.firstWhere((st) => st.role == 'cashier');
    final pkg = s.packages.first;
    final pmCash = s.payments[0];
    final pmQr = s.payments[1];
    final pmTransfer = s.payments[2];
    final order = calcOrder(s.shop, pkg, 2, 0, 0, <AddonLineInput>[
      AddonLineInput(addon: s.addons.first, qty: 2),
    ]);
    for (var i = 1; i <= 12; i++) {
      final method = i % 3 == 0 ? pmTransfer : (i.isEven ? pmQr : pmCash);
      final staff = i == 12 ? owner : cashier;
      makeBill(
        s,
        id: 'b$i',
        at: fixedNow
            .subtract(Duration(minutes: 30 - i))
            .toUtc()
            .toIso8601String(),
        tableId: 't1',
        staffId: staff.id,
        packageId: pkg.id,
        order: order,
        method: method,
        received: 50000,
      );
    }
    voidBill(s, billId: 'b12', me: owner, reason: 'ทดสอบยกเลิก', now: fixedNow);
  });
}

class _OlderDaysRepo extends Fake implements PosRepository {
  new(this.state, this.fetch);

  @override
  final PosState state;
  final Future<List<BillRecord>> Function(String date) fetch;

  @override
  Stream<PosState> get stream => const Stream<PosState>.empty();

  @override
  Future<List<BillRecord>> billsForDay(String date) => fetch(date);
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 18);

  group('BillsCubit', () {
    blocTest<BillsCubit, BillsState>(
      'paginates 12 bills into 10 rows on page 1 and 2 rows on page 2',
      build: () => BillsCubit(_buildSeededBillsRepo(fixedNow), now: fixedNow),
      act: (cubit) => cubit
        ..setPage(2)
        ..setPage(1),
      expect: () => <Matcher>[
        isA<BillsState>()
            .having((s) => s.currentPage, 'currentPage', 2)
            .having((s) => s.pagedBills.length, 'pagedBills.length', 2),
        isA<BillsState>()
            .having((s) => s.currentPage, 'currentPage', 1)
            .having((s) => s.pagedBills.length, 'pagedBills.length', 10)
            .having((s) => s.pagedBills.first.id, 'first.id', 'b12'),
      ],
    );

    blocTest<BillsCubit, BillsState>(
      'filters by payment method, bill status (ok/void), and clearFilters',
      build: () => BillsCubit(_buildSeededBillsRepo(fixedNow), now: fixedNow),
      act: (cubit) {
        cubit
          ..toggleMethodFilter('pm3') // transfer: b3, b6, b9, b12 (4 bills)
          ..setStatusFilter('void') // only b12 is voided
          ..setStatusFilter('ok') // b3, b6, b9 (3 bills)
          ..clearFilters();
      },
      expect: () => <Matcher>[
        isA<BillsState>()
            .having((s) => s.filteredBills.length, 'pm3 count', 4)
            .having((s) => s.activeFilterCount, 'activeFilterCount', 1),
        isA<BillsState>()
            .having((s) => s.filteredBills.length, 'pm3 + void count', 1)
            .having((s) => s.filteredBills.first.id, 'voided id', 'b12')
            .having((s) => s.activeFilterCount, 'activeFilterCount', 2),
        isA<BillsState>().having(
          (s) => s.filteredBills.length,
          'pm3 + ok count',
          3,
        ),
        isA<BillsState>()
            .having((s) => s.filteredBills.length, 'cleared count', 12)
            .having((s) => s.activeFilterCount, 'activeFilterCount', 0),
      ],
    );

    blocTest<BillsCubit, BillsState>(
      'filters by search query across bill no, table, method, and cashier',
      build: () => BillsCubit(_buildSeededBillsRepo(fixedNow), now: fixedNow),
      act: (cubit) {
        // The owner rang up b12; read the name so renaming staff in the
        // fixture does not break the search.
        final owner = cubit.state.posState.staff.firstWhere(
          (s) => s.role == 'owner',
        );
        cubit
          ..setSearchQuery('261104-005')
          ..setSearchQuery(owner.name);
      },
      expect: () => <Matcher>[
        isA<BillsState>()
            .having((s) => s.filteredBills.length, 'by bill no', 1)
            .having((s) => s.filteredBills.first.id, 'id', 'b5'),
        isA<BillsState>()
            .having((s) => s.filteredBills.length, 'by cashier name', 1)
            .having((s) => s.filteredBills.first.id, 'id', 'b12'),
      ],
    );

    test(
      'cashier cannot void bills while owner can void and restore stock',
      () async {
        final repo = _buildSeededBillsRepo(fixedNow);
        final cubit = BillsCubit(repo, now: fixedNow);
        addTearDown(cubit.close);

        final cashier = repo.state.staff.firstWhere((s) => s.role == 'cashier');
        final owner = repo.state.staff.firstWhere((s) => s.role == 'owner');
        final stockBefore = repo.state.addons.first.stock;

        expect(
          await cubit.voidBillById(
            staff: cashier,
            billId: 'b1',
            reason: 'ไม่ควรผ่าน',
          ),
          isFalse,
        );
        expect(
          repo.state.sales.firstWhere((b) => b.id == 'b1').voided,
          isFalse,
        );
        expect(repo.state.addons.first.stock, stockBefore);

        expect(
          await cubit.voidBillById(
            staff: owner,
            billId: 'b1',
            reason: 'ลูกค้าเปลี่ยนแพ็กเกจ',
          ),
          isTrue,
        );
        final voidedBill = repo.state.sales.firstWhere((b) => b.id == 'b1');
        expect(voidedBill.voided, isTrue);
        expect(voidedBill.voidReason, 'ลูกค้าเปลี่ยนแพ็กเกจ');
        expect(repo.state.addons.first.stock, stockBefore + 2);
      },
    );
  });

  group('BillsCubit older days', () {
    final base = _buildSeededBillsRepo(fixedNow).state;
    final old = base.sales.first;
    const oldDay = '2026-10-01';
    PosState withRawFrom() => base.copy()..rawFrom = '2026-10-29';

    test('a day before rawFrom is fetched on demand', () async {
      final asked = <String>[];
      final cubit = BillsCubit(
        _OlderDaysRepo(withRawFrom(), (d) async {
          asked.add(d);
          return <BillRecord>[old];
        }),
        now: fixedNow,
      )..setDate(oldDay);
      await Future<void>.delayed(Duration.zero);

      expect(asked, <String>[oldDay]);
      expect(cubit.state.isOlderDay, isTrue);
      expect(cubit.state.dayBills.map((b) => b.id), <String>[old.id]);
      expect(cubit.state.olderFailed, isFalse);
      expect(cubit.state.availableDates, contains(oldDay));
      await cubit.close();
    });

    test('a failed fetch sets olderFailed and shows no bills', () async {
      final cubit = BillsCubit(
        _OlderDaysRepo(withRawFrom(), (_) async => throw Exception('offline')),
        now: fixedNow,
      )..setDate(oldDay);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.olderFailed, isTrue);
      expect(cubit.state.dayBills, isEmpty);
      await cubit.close();
    });

    test('a day inside the raw window is not fetched', () async {
      var calls = 0;
      final cubit = BillsCubit(
        _OlderDaysRepo(withRawFrom(), (_) async {
          calls++;
          return <BillRecord>[];
        }),
        now: fixedNow,
      )..setDate('2026-11-03');
      await Future<void>.delayed(Duration.zero);

      expect(calls, 0);
      expect(cubit.state.isOlderDay, isFalse);
      await cubit.close();
    });
  });
}
