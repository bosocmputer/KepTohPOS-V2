import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/widgets/receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BillRecord _bill({String? replaces}) => BillRecord.fromJson(<String, dynamic>{
  'id': 'b2',
  'no': '00000-POS01-000002',
  'date': '2026-11-09',
  'at': '2026-11-09T12:30:00',
  'subtotal': 10000,
  'total': 10000,
  'received': 10000,
  'replacesBillId': ?replaces,
});

Future<void> _pump(WidgetTester tester, BillRecord bill, {String? no}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReceiptCard(
            shop: const ShopConfig(name: 'ร้านทดสอบ'),
            bill: bill,
            replacesNo: no,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('reissued receipt names the bill it replaces', (tester) async {
    await _pump(tester, _bill(replaces: 'b1'), no: '00000-POS01-000001');
    expect(
      find.text('ยกเลิกและออกฉบับใหม่แทนเลขที่ 00000-POS01-000001'),
      findsOneWidget,
    );
  });

  testWidgets('falls back when the old number is unknown', (tester) async {
    await _pump(tester, _bill(replaces: 'b1'));
    expect(find.text('ออกแทนฉบับเดิม'), findsOneWidget);
  });

  testWidgets('normal receipt has no replacement line', (tester) async {
    await _pump(tester, _bill(), no: 'x');
    expect(find.textContaining('ออกแทน'), findsNothing);
    expect(find.textContaining('ยกเลิกและออก'), findsNothing);
  });
}
