import 'package:app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

SalesTaxRow _row(String no, int total, {bool voided = false, String? rep}) =>
    SalesTaxRow(
      businessDate: '2026-11-09',
      at: '2026-11-09T05:00:00Z',
      no: no,
      docType: 'abb',
      deviceCode: 'D1',
      base: total - 700,
      vat: 700,
      total: total,
      voided: voided,
      voidReason: voided ? 'คีย์ผิด, ขอแก้' : null,
      replacesNo: rep,
    );

void main() {
  test('satangToBaht2 keeps two decimals', () {
    expect(satangToBaht2(10700), '107.00');
    expect(satangToBaht2(5), '0.05');
    expect(satangToBaht2(-150), '-1.50');
  });

  test('CSV has BOM, both sections, voided note and non-voided totals', () {
    // Arrange
    final rows = [
      _row('A-1', 10700, voided: true),
      _row('A-2', 21400, rep: 'A-1'),
    ];
    const daily = [
      DeviceDaySummary(
        businessDate: '2026-11-09',
        deviceCode: 'D1',
        firstNo: 'A-1',
        lastNo: 'A-2',
        bills: 1,
        voided: 1,
        base: 20700,
        vat: 700,
        total: 21400,
      ),
    ];

    // Act
    final csv = buildSalesTaxCsv(rows, daily);

    // Assert
    expect(csv.startsWith('﻿รายงานภาษีขาย\n'), isTrue);
    expect(csv, contains('วันที่,เลขที่,ประเภท,'));
    expect(csv, contains('"ยกเลิก: คีย์ผิด, ขอแก้"'));
    expect(csv, contains('แทนเลขที่ A-1'));
    expect(csv, contains('2026-11-09,A-2,ย่อ,D1,,,,,207.00,7.00,214.00,'));
    expect(csv, contains('รวม (ไม่รวมที่ยกเลิก),,,,,,,,207.00,7.00,214.00,'));
    expect(csv, contains('สรุปรายวันรายเครื่อง\n'));
    expect(csv, contains('2026-11-09,D1,,A-1,A-2,1,1,207.00,7.00,214.00'));
  });

  test('CSV neutralises formula-like text but keeps negative numbers', () {
    // Arrange
    const row = SalesTaxRow(
      businessDate: '2026-11-09',
      at: '2026-11-09T05:00:00Z',
      no: 'A-9',
      docType: 'full',
      deviceCode: 'D1',
      buyerName: '=HYPERLINK("http://x","y")',
      buyerBranch: '@SUM(1)',
      base: -100,
      vat: 0,
      total: -100,
      voided: false,
    );

    // Act
    final csv = buildSalesTaxCsv(const [row], const []);

    // Assert
    expect(csv, contains('"\'=HYPERLINK(""http://x"",""y"")"'));
    expect(csv, contains("'@SUM(1)"));
    expect(csv, contains(',-1.00,0.00,-1.00,'));
    expect(csv, isNot(contains(',=HYPERLINK')));
  });
}
