import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// End-to-end: QR payment, void with a reason, a cash sale, closing the shift
/// and the profit overview before the day is closed. Covers SA-03, BI-02,
/// SH-02 and part of DA-01.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QR sale is voided, cash sale kept, shift closes exactly', (
    tester,
  ) async {
    // Arrange
    final e2e = await createShop(tester);
    final owner = await ownerClient(e2e.email, e2e.password);
    final shopId = await shopIdOf(owner, e2e);
    await owner
        .from('shops')
        .update(<String, dynamic>{'promptpay': '0812345678'})
        .eq('id', shopId);
    await owner.from('packages').insert(<String, dynamic>{
      'shop_id': shopId,
      'name': 'บุฟเฟต์ 399',
      'adult_price': 39900,
      'child_price': 19900,
    });
    await owner.from('dining_tables').insert(<String, dynamic>{
      'shop_id': shopId,
      'name': 'A1',
      'seats': 4,
    });
    await owner.from('addons').insert(<String, dynamic>{
      'shop_id': shopId,
      'name': 'โค้ก',
      'category': 'เครื่องดื่ม',
      'price': 4500,
      'cost': 3000,
      'stock': 24,
    });
    await signInAndOpenShift(tester, '1234');

    // Act: 2 adults paid by QR, then voided.
    await tapOn(tester, find.text('+ เปิดโต๊ะ'));
    await tapKey(tester, 'sale-pay-btn');
    await tapOn(tester, find.text('พร้อมเพย์ QR'));
    await tapKey(tester, 'pay-confirm-btn');
    await waitForServer(tester);
    await tapKey(tester, 'receipt-void-btn');
    await tapKey(tester, 'void-preset-ลูกค้าเปลี่ยนใจไม่รับประทาน');
    await tapKey(tester, 'confirm-void-btn');
    await waitForServer(tester);

    // Act: the same table again, 2 adults + a Coke, exact cash.
    await waitFor(tester, find.byKey(const ValueKey('sale-pay-btn')));
    await tapOn(tester, find.textContaining('เครื่องดื่ม'));
    await tapOn(tester, find.text('โค้ก'));
    await tapKey(tester, 'sale-pay-btn');
    await tapKey(tester, 'pay-confirm-btn');
    await waitForServer(tester);
    await tapKey(tester, 'receipt-done-btn');
    await waitForServer(tester);

    // Act: close the shift with exactly the expected cash.
    await tapKey(tester, 'shell-menu-btn');
    await tapKey(tester, 'drawer-nav-shift');
    await tapKey(tester, 'shift-fill-expected-btn');
    expect(find.textContaining('1,843'), findsWidgets);
    await tapKey(tester, 'close-shift-btn');
    // The confirm dialog's "ปิดกะ" is the last one on screen.
    await waitFor(tester, find.text('ปิดกะ').at(1));
    await tester.tap(find.text('ปิดกะ').last);
    await waitForServer(tester);

    // Assert: server records.
    final bills = await owner
        .from('bills')
        .select('total, method_type, voided')
        .eq('shop_id', shopId)
        .order('at', ascending: true);
    expect(bills, <Map<String, dynamic>>[
      <String, dynamic>{'total': 79800, 'method_type': 'qr', 'voided': true},
      <String, dynamic>{'total': 84300, 'method_type': 'cash', 'voided': false},
    ]);
    final shift = await owner
        .from('shifts')
        .select('closed_at, counted')
        .eq('shop_id', shopId)
        .single();
    expect(shift['closed_at'], isNotNull);
    expect(shift['counted'], 184300);

    // Assert: the profit overview counts only the kept sale.
    await tapKey(tester, 'shell-menu-btn');
    await tapKey(tester, 'drawer-nav-dashboard');
    // Profit waits for the day's stock count, so only sales show for now.
    await waitFor(tester, find.textContaining('฿843'));
    await waitFor(tester, find.text('วันนี้ยังไม่ปิดยอด'));
  });
}
