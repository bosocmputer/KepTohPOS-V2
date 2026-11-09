import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock tax report lists voided + replacement and sums per day', () async {
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
    final old = repo.state.sales.last;
    await repo.reissueBill(billId: old.id, reason: 'แก้ช่องทาง');

    // Act
    final rows = await repo.getSalesTaxReport(old.date.substring(0, 7));
    final daily = await repo.getDailyDeviceSummary(old.date, old.date);

    // Assert
    final voided = rows.firstWhere((r) => r.no == old.no);
    expect(voided.voided, isTrue);
    expect(voided.voidReason, 'แก้ช่องทาง');
    expect(rows.firstWhere((r) => r.replacesNo == old.no).voided, isFalse);
    expect(daily, hasLength(1));
    expect(daily.single.voided, 1);
    expect(daily.single.bills, 1);
    expect(daily.single.total, old.total);
    expect(daily.single.base + daily.single.vat, daily.single.total);
  });
}
