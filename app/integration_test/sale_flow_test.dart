import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// End-to-end: a new owner sets up a shop and sells through the real UI on a
/// local Supabase stack. Covers ON-01, ON-03, AU-01, SH-01, SA-01, SA-02.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('owner opens a shop and sells a pay-later table for cash', (
    tester,
  ) async {
    // Arrange: sign up and create the shop with PIN 1234 entered twice.
    final e2e = await createShop(tester);

    // Catalog set up directly; the setup screens have their own test.
    final owner = await ownerClient(e2e.email, e2e.password);
    final shopId = await shopIdOf(owner, e2e);
    await owner.from('packages').insert(<String, dynamic>{
      'shop_id': shopId,
      'name': 'บุฟเฟต์ 399',
      'adult_price': 39900,
      'child_price': 19900,
      'time_limit_min': 120,
    });
    await owner.from('dining_tables').insert(<String, dynamic>{
      'shop_id': shopId,
      'name': 'A1',
      'seats': 4,
    });
    await owner.from('addons').insert(<Map<String, dynamic>>[
      <String, dynamic>{
        'shop_id': shopId,
        'name': 'โค้ก',
        'category': 'เครื่องดื่ม',
        'price': 4500,
        'cost': 3000,
        'stock': 24,
      },
      <String, dynamic>{
        'shop_id': shopId,
        'name': 'เบียร์',
        'category': 'เครื่องดื่ม',
        'price': 9000,
        'cost': 6200,
        'stock': 24,
      },
    ]);

    // Act: sign in with the PIN and open the shift.
    await signInAndOpenShift(tester, '1234');

    // Act: table A1, pay later, 2 adults + 1 child, two rounds of drinks.
    await tapOn(tester, find.text('+ เปิดโต๊ะ'));
    await tapOn(tester, find.text('กินก่อนจ่าย'));
    await tapStepperPlus(tester, 'people-stepper-c');
    await tapOn(tester, find.textContaining('เครื่องดื่ม'));
    await tapOn(tester, find.text('โค้ก'));
    await tapKey(tester, 'sale-send-round-btn');
    await waitForServer(tester);
    await waitFor(tester, find.text('ส่งออเดอร์แล้ว · รอชำระ'));
    await tapOn(tester, find.text('เบียร์'));
    await tapOn(tester, find.text('เบียร์'));
    await tapKey(tester, 'sale-send-round-btn');
    await waitForServer(tester);
    await waitFor(tester, find.textContaining('1,222'));

    // Act: pay ฿1,300 in cash.
    await tapKey(tester, 'sale-pay-btn');
    await tapOn(tester, find.text('฿1,300'));
    await tapKey(tester, 'pay-confirm-btn');
    await waitForServer(tester);
    await waitFor(tester, find.byKey(const ValueKey('receipt-modal')));

    // Assert: the receipt and the server agree.
    expect(textOf(tester, 'receipt-total-amount'), contains('1,222'));
    final bills = await owner
        .from('bills')
        .select('no, total, received, change_amount, method_type')
        .eq('shop_id', shopId);
    expect(bills, hasLength(1));
    expect(bills.single['total'], 122200);
    expect(bills.single['received'], 130000);
    expect(bills.single['change_amount'], 7800);
    expect(bills.single['method_type'], 'cash');
    final addons = await owner
        .from('addons')
        .select('name, stock')
        .eq('shop_id', shopId)
        .order('name');
    expect(
      {for (final a in addons) a['name']: a['stock']},
      <String, int>{'เบียร์': 22, 'โค้ก': 23},
    );
  });
}

/// Taps the "+" end of a people stepper.
Future<void> tapStepperPlus(WidgetTester tester, String key) async {
  final stepper = find.byKey(ValueKey(key));
  await waitFor(tester, stepper);
  final box = tester.getRect(stepper.first);
  await tester.tapAt(Offset(box.right - 12, box.center.dy));
  await tester.pump(const Duration(milliseconds: 200));
}
