import 'dart:convert';
import 'dart:io';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

PosState _loadFreshMockState(DateTime now) {
  Map<String, dynamic> readObj(String name) =>
      jsonDecode(File('assets/mock/$name.json').readAsStringSync())
          as Map<String, dynamic>;
  List<Map<String, dynamic>> readList(String name) => (jsonDecode(
    File('assets/mock/$name.json').readAsStringSync(),
  ) as List<dynamic>).cast<Map<String, dynamic>>();

  return PosState(
    startDate: dkey(now),
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
    shifts: <ShiftRecord>[
      ShiftRecord(
        id: 'sh1',
        staffId: 'st1',
        openedAt: now
            .subtract(const Duration(hours: 2))
            .toUtc()
            .toIso8601String(),
        floatAmount: 1000,
      ),
    ],
  );
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 12);
  const ownerStaff = StaffMember(
    id: 'st1',
    name: 'พี่ต้อม (เจ้าของร้าน)',
    role: 'owner',
    pin: '1111',
  );
  const cashierStaff = StaffMember(
    id: 'st3',
    name: 'น้องมายด์',
    role: 'cashier',
    pin: '0000',
  );

  group('SaleBloc', () {
    blocTest<SaleBloc, SaleState>(
      'adds/removes items and updates head counts on a selected package',
      build: () => SaleBloc(
        MockPosRepository.fromState(_loadFreshMockState(fixedNow)),
        initialTableId: 't1',
        now: fixedNow,
      ),
      act: (bloc) => bloc
        ..add(const SalePackageSelected('pk2'))
        ..add(const SaleHeadsChanged(a: 2))
        ..add(const SaleHeadsChanged(c: 1))
        ..add(const SaleAddonIncremented('ad1'))
        ..add(const SaleAddonIncremented('ad1'))
        ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 1))
        ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 0)),
      verify: (bloc) {
        final s = bloc.state;
        expect(s.pkgId, 'pk2');
        expect(s.a, 2);
        expect(s.c, 1);
        expect(s.ad.containsKey('ad1'), isFalse);
        expect(s.cartOrder.total, 697);
      },
    );

    blocTest<SaleBloc, SaleState>(
      'sends 2 rounds matching order_settle_test.dart (due = 1540)',
      build: () => SaleBloc(
        MockPosRepository.fromState(_loadFreshMockState(fixedNow)),
        initialTableId: 't2',
        now: fixedNow,
      ),
      act: (bloc) => bloc
        ..add(const SaleTimingChanged('after'))
        ..add(const SalePackageSelected('pk2'))
        ..add(const SaleHeadsChanged(a: 3))
        ..add(const SaleHeadsChanged(c: 1))
        ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 3))
        ..add(const SaleAddonQtyChanged(addonId: 'ad5', qty: 2))
        ..add(const SaleRoundSent(staff: ownerStaff))
        ..add(const SaleHeadsChanged(a: 1))
        ..add(const SaleAddonQtyChanged(addonId: 'ad5', qty: 1))
        ..add(const SaleRoundSent(staff: ownerStaff)),
      verify: (bloc) {
        final s = bloc.state;
        expect(s.openTable, isNotNull);
        expect(s.openTable!.rounds.length, 2);
        expect(s.due, 1540);
        expect(s.payOrder.total, 1540);

        final ad5 = s.posState.addons.firstWhere((x) => x.id == 'ad5');
        expect(ad5.stock, 57);
      },
    );

    test(
      'cashier is rejected on adjustSent while owner reduces 1540 to 1181',
      () async {
        final repo = MockPosRepository.fromState(_loadFreshMockState(fixedNow));
        final bloc = SaleBloc(repo, initialTableId: 't2', now: fixedNow)
          ..add(const SaleTimingChanged('after'))
          ..add(const SalePackageSelected('pk2'))
          ..add(const SaleHeadsChanged(a: 3))
          ..add(const SaleHeadsChanged(c: 1))
          ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 3))
          ..add(const SaleAddonQtyChanged(addonId: 'ad5', qty: 2))
          ..add(const SaleRoundSent(staff: ownerStaff))
          ..add(const SaleHeadsChanged(a: 1))
          ..add(const SaleAddonQtyChanged(addonId: 'ad5', qty: 1))
          ..add(const SaleRoundSent(staff: ownerStaff));

        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.due, 1540);

        // Cashier attempt must be rejected
        bloc.add(
          const SaleSentItemAdjusted(
            kind: 'head',
            key: 'a',
            qty: 1,
            reason: 'แคชเชียร์ลองลดหัว',
            staff: cashierStaff,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.toastMessage, 'ผู้จัดการขึ้นไปเท่านั้น');
        expect(bloc.state.due, 1540);

        // Owner adjusts 1 adult head + 1 beer (ad5) -> 1540 -> 1181
        bloc
          ..add(
            const SaleSentItemAdjusted(
              kind: 'head',
              key: 'a',
              qty: 1,
              reason: 'ลดหัวผู้ใหญ่ 1',
              staff: ownerStaff,
            ),
          )
          ..add(
            const SaleSentItemAdjusted(
              kind: 'addon',
              key: 'ad5',
              qty: 1,
              reason: 'คืนเบียร์ 1',
              staff: ownerStaff,
            ),
          );
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.due, 1181);
        expect(bloc.state.payOrder.total, 1181);
        final ad5After = bloc.state.posState.addons.firstWhere(
          (x) => x.id == 'ad5',
        );
        expect(ad5After.stock, 58);

        await bloc.close();
      },
    );

    blocTest<SaleBloc, SaleState>(
      'pay-before cash 1000 settles bill 607 with change 393 & deducts stock',
      build: () => SaleBloc(
        MockPosRepository.fromState(_loadFreshMockState(fixedNow)),
        initialTableId: 't1',
        now: fixedNow,
      ),
      act: (bloc) => bloc
        ..add(const SaleTimingChanged('before'))
        ..add(const SalePackageSelected('pk1'))
        ..add(const SaleHeadsChanged(a: 2, c: 1, f: 1))
        ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 2))
        ..add(const SaleAddonQtyChanged(addonId: 'ad5', qty: 1))
        ..add(const SalePaymentStepChanged('pay'))
        ..add(const SalePaymentMethodSelected('pm1'))
        ..add(const SaleCashReceivedChanged('1000'))
        ..add(
          SalePaymentSubmitted(staff: ownerStaff, billId: 'b1', now: fixedNow),
        ),
      verify: (bloc) {
        final s = bloc.state;
        final bill = s.settledBill;
        expect(bill, isNotNull);
        expect(bill!.no, '261104-001');
        expect(bill.total, 607);
        expect(bill.received, 1000);
        expect(bill.change, 393);
        expect(s.openTable, isNotNull);
        expect(s.openTable!.billIds, contains('b1'));

        final ad1 = s.posState.addons.firstWhere((x) => x.id == 'ad1');
        final ad5 = s.posState.addons.firstWhere((x) => x.id == 'ad5');
        expect(ad1.stock, 94);
        expect(ad5.stock, 59);
      },
    );

    blocTest<SaleBloc, SaleState>(
      'eat-before-paying PromptPay settles 2 rounds + adjust + extra = 1196',
      build: () => SaleBloc(
        MockPosRepository.fromState(_loadFreshMockState(fixedNow)),
        initialTableId: 't2',
        now: fixedNow,
      ),
      act: (bloc) => bloc
        ..add(const SaleTimingChanged('after'))
        ..add(const SalePackageSelected('pk2'))
        ..add(const SaleHeadsChanged(a: 3, c: 1))
        ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 3))
        ..add(const SaleAddonQtyChanged(addonId: 'ad5', qty: 2))
        ..add(const SaleRoundSent(staff: ownerStaff))
        ..add(const SaleHeadsChanged(a: 1))
        ..add(const SaleAddonQtyChanged(addonId: 'ad5', qty: 1))
        ..add(const SaleRoundSent(staff: ownerStaff))
        ..add(
          const SaleSentItemAdjusted(
            kind: 'head',
            key: 'a',
            qty: 1,
            reason: 'ลดหัวผู้ใหญ่ 1',
            staff: ownerStaff,
          ),
        )
        ..add(
          const SaleSentItemAdjusted(
            kind: 'addon',
            key: 'ad5',
            qty: 1,
            reason: 'คืนเบียร์ 1',
            staff: ownerStaff,
          ),
        )
        ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 1))
        ..add(const SalePaymentStepChanged('pay'))
        ..add(const SalePaymentMethodSelected('pm2'))
        ..add(
          SalePaymentSubmitted(staff: ownerStaff, billId: 'b2', now: fixedNow),
        ),
      verify: (bloc) {
        final s = bloc.state;
        final bill = s.settledBill;
        expect(bill, isNotNull);
        expect(bill!.no, '261104-001');
        expect(bill.total, 1196);
        expect(bill.received, 1196);
        expect(bill.change, 0);
        expect(s.openTable, isNotNull);
        expect(s.openTable!.rounds, isEmpty);
        expect(s.openTable!.adjusts, isEmpty);
        expect(s.due, 0);

        final ad1 = s.posState.addons.firstWhere((x) => x.id == 'ad1');
        expect(ad1.stock, 92);
      },
    );

    blocTest<SaleBloc, SaleState>(
      'insufficient cash received blocks settlement',
      build: () => SaleBloc(
        MockPosRepository.fromState(_loadFreshMockState(fixedNow)),
        initialTableId: 't1',
        now: fixedNow,
      ),
      act: (bloc) => bloc
        ..add(const SaleTimingChanged('before'))
        ..add(const SalePackageSelected('pk1'))
        ..add(const SaleHeadsChanged(a: 2, c: 1, f: 1))
        ..add(const SaleAddonQtyChanged(addonId: 'ad1', qty: 2))
        ..add(const SaleAddonQtyChanged(addonId: 'ad5', qty: 1))
        ..add(const SalePaymentStepChanged('pay'))
        ..add(const SalePaymentMethodSelected('pm1'))
        ..add(const SaleCashReceivedChanged('500'))
        ..add(
          SalePaymentSubmitted(
            staff: ownerStaff,
            billId: 'b_fail',
            now: fixedNow,
          ),
        ),
      verify: (bloc) {
        final s = bloc.state;
        expect(s.canConfirmPayment, isFalse);
        expect(s.settledBill, isNull);
        expect(s.posState.sales, isEmpty);
        expect(s.toastMessage, 'จำนวนเงินที่รับยังไม่ครบ');
      },
    );
  });
}
