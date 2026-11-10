import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/data/supabase/supabase_pos_base.dart';
import 'package:app/core/data/supabase/supabase_state_loader.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _StubPosBase extends SupabasePosBase {
  new(PosState state)
    : super(
        deviceClient: SupabaseClient('http://localhost', 'anon'),
        ownerClient: null,
        shopId: 'shop-1',
        snapshot: SupabaseSnapshot(
          state: state,
          sessionByTable: const <String, String>{},
          organizationId: 'org-1',
          canReadCosts: true,
        ),
      );
}

void main() {
  final fixedNow = DateTime(2026, 11, 9, 12);
  late PosRepository repo;
  late BillsCubit cubit;

  setUp(() {
    repo = MockPosRepository.createFallback(now: fixedNow)
      ..update((s) {
        final pkg = s.packages.first;
        makeBill(
          s,
          id: 'b1',
          at: fixedNow.toUtc().toIso8601String(),
          tableId: 't1',
          staffId: s.staff.first.id,
          packageId: pkg.id,
          order: calcOrder(s.shop, pkg, 2, 0, 0, const <AddonLineInput>[]),
          method: s.payments.first,
          received: 50000,
        );
      });
    cubit = BillsCubit(repo, now: fixedNow);
  });
  tearDown(() => cubit.close());

  test('reissueBill voids the old bill and selects the new one', () async {
    final old = repo.state.sales.firstWhere((b) => b.id == 'b1');
    await cubit.reissueBill(billId: 'b1', reason: 'เปลี่ยนช่องทาง');

    final created = cubit.state.selectedBill!;
    expect(created.id, isNot('b1'));
    expect(created.replacesBillId, 'b1');
    expect(repo.state.sales.firstWhere((b) => b.id == 'b1').voided, isTrue);
    expect(cubit.state.toastMessage, contains(created.no));
    expect(cubit.state.replacesNoOf(created), old.no);
  });

  test('reissueBill rethrows command failures and selects nothing', () async {
    await cubit.reissueBill(billId: 'b1', reason: 'x');
    cubit.selectBill(null);
    await expectLater(
      cubit.reissueBill(billId: 'b1', reason: 'อีกครั้ง'),
      throwsA(isA<PosCommandException>()),
    );
    expect(cubit.state.selectedBillId, isNull);
  });

  test('canReissue: staff role, voided and previous month', () async {
    final bill = repo.state.sales.firstWhere((b) => b.id == 'b1');
    final owner = repo.state.staff.firstWhere((s) => s.role == 'owner');
    final cashier = repo.state.staff.firstWhere((s) => s.role == 'cashier');
    expect(cubit.state.canReissue(bill, owner), isTrue);
    expect(cubit.state.canReissue(bill, cashier), isFalse);
    final lastMonth = BillRecord.fromJson(<String, dynamic>{
      ...bill.toJson(),
      'date': '2026-10-31',
    });
    expect(cubit.state.canReissue(lastMonth, owner), isFalse);
    final fullInv = BillRecord.fromJson(<String, dynamic>{
      ...bill.toJson(),
      'isFullInvoice': true,
    });
    expect(cubit.state.canReissue(fullInv, owner), isFalse);
    await cubit.reissueBill(billId: 'b1', reason: 'x');
    final voided = repo.state.sales.firstWhere((b) => b.id == 'b1');
    expect(cubit.state.canReissue(voided, owner), isFalse);
  });

  test('describeError maps PostgrestException 23514 to Thai message', () async {
    final base = _StubPosBase(repo.state);
    addTearDown(base.controller.close);
    final ex = base.describeError(
      const PostgrestException(message: 'check', code: '23514'),
    );
    expect(ex, isA<PosCommandException>());
    expect(ex.message, 'ข้อมูลไม่ถูกต้องตามเงื่อนไขที่กำหนด');
  });
}
