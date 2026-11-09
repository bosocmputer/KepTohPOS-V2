import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock reissue voids the old bill and links the new one', () async {
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
    final created = await repo.reissueBill(
      billId: old.id,
      reason: 'เปลี่ยนวิธีจ่าย',
    );

    // Assert
    final sales = repo.state.sales;
    expect(sales.firstWhere((b) => b.id == old.id).voided, isTrue);
    expect(created.replacesBillId, old.id);
    expect(created.id, isNot(old.id));
    expect(created.no, isNot(old.no));
    expect(created.total, old.total);
    expect(created.voided, isFalse);
    expect(sales.any((b) => b.id == created.id), isTrue);
  });
}
