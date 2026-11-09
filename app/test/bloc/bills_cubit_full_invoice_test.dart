import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('issueFullInvoice selects the new full-invoice bill', () async {
    await cubit.issueFullInvoice(
      billId: 'b1',
      buyerName: 'สมชาย',
      buyerAddress: '1 ถนน',
    );
    final created = cubit.state.selectedBill!;
    expect(created.id, isNot('b1'));
    expect(created.isFullInvoice, isTrue);
    expect(cubit.state.toastMessage, contains(created.no));
  });
}
