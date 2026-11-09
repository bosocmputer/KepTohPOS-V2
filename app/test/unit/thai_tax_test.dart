import 'package:app/core/utils/thai_tax.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tax id normalize/validate', () {
    expect(normalizeTaxId('0 1055-61234 567'), '0105561234567');
    expect(isValidTaxId('0-1055-61234-56-7'), isTrue);
    expect(isValidTaxId('0105561234567'), isTrue);
    expect(isValidTaxId('010556123456'), isFalse);
    expect(isValidTaxId('01055612345ab'), isFalse);
  });

  test('branch code + label', () {
    expect(isValidBranchCode('00001'), isTrue);
    expect(isValidBranchCode('0001'), isFalse);
    expect(isValidBranchCode('abcde'), isFalse);
    expect(branchLabel('00000'), 'สำนักงานใหญ่');
    expect(branchLabel('00012'), 'สาขาที่ 00012');
  });

  test('recentMonths newest first across year boundary', () {
    expect(recentMonths(DateTime(2026, 2, 10), 3), [
      '2026-02',
      '2026-01',
      '2025-12',
    ]);
  });

  test('lastDayOfMonth', () {
    expect(lastDayOfMonth(2024, 2), 29);
    expect(lastDayOfMonth(2026, 2), 28);
    expect(lastDayOfMonth(2026, 12), 31);
  });
}
