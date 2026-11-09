import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/widgets/receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BillRecord _bill({String? taxId, String? branch}) =>
    BillRecord.fromJson(<String, dynamic>{
      'id': 'f1',
      'no': '00000-F-000001',
      'date': '2026-11-09',
      'at': '2026-11-09T12:30:00',
      'subtotal': 10000,
      'vat': 654,
      'total': 10000,
      'received': 10000,
      'vatMode': 'included',
      'vatRate': 7,
      'isTaxInvoice': true,
      'replacesBillId': 'b1',
      'isFullInvoice': true,
      'buyerName': 'บริษัท ลูกค้า จำกัด',
      'buyerAddress': '99 ถ.สุขุมวิท กรุงเทพฯ',
      'buyerTaxId': ?taxId,
      'buyerBranch': ?branch,
    });

Future<void> _pump(WidgetTester tester, BillRecord bill) async {
  tester.view.physicalSize = const Size(900, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReceiptCard(
            shop: const ShopConfig(
              name: 'ร้านทดสอบ',
              taxId: '0105500000001',
              address: '1 ถนนหลัก',
            ),
            bill: bill,
            replacesNo: '00000-POS01-000001',
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('full invoice shows title, buyer with tax id and reference', (
    tester,
  ) async {
    await _pump(tester, _bill(taxId: '0105512345678', branch: '00001'));
    expect(find.text('ใบกำกับภาษี/ใบเสร็จรับเงิน'), findsOneWidget);
    expect(find.text('ผู้ซื้อ: บริษัท ลูกค้า จำกัด'), findsOneWidget);
    expect(find.text('99 ถ.สุขุมวิท กรุงเทพฯ'), findsOneWidget);
    expect(
      find.text('เลขประจำตัวผู้เสียภาษี: 0105512345678 (สาขาที่ 00001)'),
      findsOneWidget,
    );
    expect(
      find.text('ออกแทนใบกำกับภาษีอย่างย่อ/ใบเสร็จเลขที่ 00000-POS01-000001'),
      findsOneWidget,
    );
    expect(find.text('เลขประจำตัวผู้เสียภาษี: 0105500000001'), findsNothing);
    expect(find.text('เลขผู้เสียภาษี 0105500000001'), findsOneWidget);
    expect(find.text('มูลค่าก่อนภาษี'), findsOneWidget);
  });

  testWidgets('buyer without tax id omits the tax id line', (tester) async {
    await _pump(tester, _bill());
    expect(find.text('ผู้ซื้อ: บริษัท ลูกค้า จำกัด'), findsOneWidget);
    expect(find.textContaining('เลขประจำตัวผู้เสียภาษี'), findsNothing);
  });

  testWidgets('abbreviated receipt has no buyer block', (tester) async {
    await _pump(
      tester,
      BillRecord.fromJson(<String, dynamic>{
        ..._bill().toJson(),
        'isFullInvoice': false,
      }),
    );
    expect(find.byKey(const ValueKey('receipt-buyer-block')), findsNothing);
    expect(find.text('ใบกำกับภาษี/ใบเสร็จรับเงิน'), findsNothing);
  });
}
