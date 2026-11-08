import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// End-to-end: the owner records a purchase and an expense on screen; a
/// cashier then sees today's rows without any amounts and cannot edit or
/// delete them. Covers ST-01, ST-03, ST-04 and ST-05.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder keyStartingWith(String prefix) => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith(prefix),
  );

  Future<void> openStockTab(WidgetTester tester, String label) async {
    await tapOn(tester, find.text(label).last);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('cashier sees stock entries without costs or edit buttons', (
    tester,
  ) async {
    // Arrange
    final e2e = await createShop(tester);
    final owner = await ownerClient(e2e.email, e2e.password);
    final shopId = await shopIdOf(owner, e2e);
    final supplier = await owner
        .from('suppliers')
        .insert(<String, dynamic>{'shop_id': shopId, 'name': 'ตลาดสด'})
        .select('id')
        .single();
    await owner.from('ingredients').insert(<String, dynamic>{
      'shop_id': shopId,
      'name': 'หมูสามชั้น',
      'unit': 'กก.',
    });
    final cashier = await owner
        .from('staff')
        .insert(<String, dynamic>{
          'shop_id': shopId,
          'name': 'แคชเชียร์ E2E',
          'role': 'cashier',
        })
        .select('id')
        .single();
    await owner.rpc<void>(
      'set_staff_pin',
      params: <String, dynamic>{'p_staff_id': cashier['id'], 'p_pin': '5678'},
    );
    await signInAndOpenShift(tester, '1234');

    // Act: the owner buys 2 kg of pork for ฿360 and pays ฿450 for ice.
    await tapKey(tester, 'shell-menu-btn');
    await tapKey(tester, 'drawer-nav-stock');
    await openStockTab(tester, 'ซื้อของ');
    await tapKey(tester, 'purchase-new-sup-${supplier['id']}');
    await tapKey(tester, 'purchase-line-ing-0');
    await tapOn(tester, find.text('หมูสามชั้น (กก.)').last);
    await typeInto(tester, 'purchase-line-qty-0', '2');
    await typeInto(tester, 'purchase-line-total-0', '360');
    await tapKey(tester, 'purchase-modal-save-btn');
    await waitForServer(tester);
    await waitGone(tester, find.byKey(const ValueKey('purchase-modal')));

    await openStockTab(tester, 'ค่าใช้จ่าย');
    await tapKey(tester, 'expense-add-btn');
    await typeInto(tester, 'expense-line-amount-0', '450');
    await typeInto(tester, 'expense-line-note-0', 'น้ำแข็ง');
    await tapKey(tester, 'expense-modal-save-btn');
    await waitForServer(tester);
    await waitGone(tester, find.byKey(const ValueKey('expense-modal')));

    // Assert: the owner sees the amount and can manage the row.
    await waitFor(tester, find.text('น้ำแข็ง'));
    expect(textOf(tester, 'expense-day-total'), contains('450'));
    expect(keyStartingWith('expense-edit-'), findsOneWidget);

    // Act: switch to the cashier.
    await tapKey(tester, 'shell-menu-btn');
    await tapKey(tester, 'sidebar-logout-btn');
    await waitFor(tester, find.text('เข้าสู่ระบบ'));
    await tapOn(tester, find.text('เจ้าของ E2E'));
    await tapOn(tester, find.text('แคชเชียร์ E2E'));
    await signInAndOpenShift(tester, '5678');
    await tapKey(tester, 'shell-menu-btn');
    await tapKey(tester, 'drawer-nav-stock');

    // Assert: expenses keep the row, hide the amount, offer no edit.
    await openStockTab(tester, 'ค่าใช้จ่าย');
    await waitFor(tester, find.text('น้ำแข็ง'));
    expect(textOf(tester, 'expense-day-total'), '–');
    expect(find.textContaining('450'), findsNothing);
    expect(keyStartingWith('expense-edit-'), findsNothing);
    expect(keyStartingWith('expense-delete-'), findsNothing);

    // Assert: the purchase is listed without its total or edit buttons.
    await openStockTab(tester, 'ซื้อของ');
    await waitFor(tester, find.textContaining('ตลาดสด'));
    expect(find.textContaining('360'), findsNothing);
    expect(keyStartingWith('purchase-edit-'), findsNothing);
    expect(keyStartingWith('purchase-delete-'), findsNothing);

    // Assert: stock value is hidden.
    await openStockTab(tester, 'คงเหลือ');
    await waitFor(tester, find.byKey(const ValueKey('balance-total-value')));
    expect(textOf(tester, 'balance-total-value'), '–');
  });
}
