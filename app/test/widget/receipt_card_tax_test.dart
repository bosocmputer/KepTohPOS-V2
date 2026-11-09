import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/widgets/receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BillRecord _bill({required bool tax}) => BillRecord(
  id: 'b',
  no: '00000-POS01-000001',
  date: '2026-11-09',
  at: '2026-11-09T12:30:00',
  tableId: 't1',
  tableName: 'A1',
  staffId: 's1',
  staffName: 'มุก',
  packageId: 'p1',
  lines: const <OrderLineItem>[],
  service: 0,
  rounding: 0,
  change: 0,
  subtotal: 10000,
  total: 10000,
  heads: HeadsCount(a: 1),
  methodId: 'm',
  methodName: 'เงินสด',
  methodType: 'cash',
  received: 10000,
  vatMode: 'included',
  vatRate: 7,
  vat: 654,
  rdMachineCode: tax ? 'ABC-123' : null,
  isTaxInvoice: tax,
);

Future<void> _pump(
  WidgetTester tester,
  ShopConfig shop,
  BillRecord bill,
) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReceiptCard(shop: shop, bill: bill),
        ),
      ),
    ),
  );
}

void main() {
  const shop = ShopConfig(
    name: 'ร้านทดสอบ',
    taxId: '0105500000001',
    vatMode: 'included',
  );

  testWidgets('tax invoice receipt shows RD fields', (tester) async {
    await _pump(tester, shop, _bill(tax: true));
    expect(find.text('ใบเสร็จรับเงิน/ใบกำกับภาษีอย่างย่อ'), findsOneWidget);
    expect(find.text('เลขรหัสประจำเครื่อง: ABC-123'), findsOneWidget);
    expect(find.text('เลขผู้เสียภาษี 0105500000001'), findsOneWidget);
    expect(find.text('สำนักงานใหญ่'), findsOneWidget);
    expect(find.text('ราคารวมภาษีมูลค่าเพิ่มแล้ว'), findsOneWidget);
    expect(find.textContaining('น.'), findsWidgets);
  });

  testWidgets('non-head-office branch prints branch number', (tester) async {
    await _pump(tester, shop.copyWith(branchCode: '00003'), _bill(tax: true));
    expect(find.text('สาขาที่ 00003'), findsOneWidget);
    expect(find.text('สำนักงานใหญ่'), findsNothing);
  });

  testWidgets('plain receipt never says tax invoice', (tester) async {
    await _pump(tester, shop, _bill(tax: false));
    expect(find.text('ใบเสร็จรับเงิน'), findsOneWidget);
    expect(find.textContaining('ใบกำกับภาษี'), findsNothing);
    expect(find.textContaining('เลขรหัสประจำเครื่อง'), findsNothing);
    expect(find.text('ราคารวมภาษีมูลค่าเพิ่มแล้ว'), findsNothing);
  });
}
