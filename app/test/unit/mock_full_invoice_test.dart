import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock full invoice voids the old bill and numbers -F-', () async {
    // Arrange
    final now = DateTime(2026, 11, 9, 12);
    final repo = MockPosRepository.createFallback(now: now)
      ..update((s) {
        final pkg = s.packages.first;
        makeBill(
          s,
          id: 'b1',
          at: now.toUtc().toIso8601String(),
          tableId: 't1',
          staffId: s.staff.first.id,
          packageId: pkg.id,
          order: calcOrder(s.shop, pkg, 2, 0, 0, <AddonLineInput>[]),
          method: s.payments.first,
          received: 50000,
        );
      });
    final old = repo.state.sales.firstWhere((b) => !b.voided);

    // Act
    final created = await repo.issueFullInvoice(
      billId: old.id,
      buyerName: 'บริษัท ก จำกัด',
      buyerAddress: '1 ถนนหลัก',
      buyerTaxId: '0105512345678',
      buyerBranch: '00000',
    );

    // Assert
    expect(repo.state.sales.firstWhere((b) => b.id == old.id).voided, isTrue);
    expect(created.isFullInvoice, isTrue);
    expect(created.replacesBillId, old.id);
    expect(created.no, matches(RegExp(r'^\d{5}-F-\d{6}$')));
    expect(created.buyerName, 'บริษัท ก จำกัด');
    expect(created.buyerTaxId, '0105512345678');
    expect(created.total, old.total);
    expect(created.voided, isFalse);
    await expectLater(
      repo.issueFullInvoice(
        billId: old.id,
        buyerName: 'x',
        buyerAddress: 'y',
      ),
      throwsA(isA<PosCommandException>()),
    );
  });
}
