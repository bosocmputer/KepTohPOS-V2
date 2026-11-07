import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// End-to-end: the owner fills in the catalog through the setup screens, adds
/// a cashier, and the cashier signs in. Covers SE-03 to SE-07, AU-01, AU-02.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openTab(WidgetTester tester, String id) async {
    await tapKey(tester, 'setup-tab-$id');
    await tapKey(tester, 'setup-add-$id-btn');
  }

  Future<void> save(WidgetTester tester) async {
    await tapKey(tester, 'setup-modal-save-btn');
    await waitForServer(tester);
    await waitGone(tester, find.byKey(const ValueKey('setup-modal-save-btn')));
  }

  testWidgets('owner sets up the shop on screen and a cashier signs in', (
    tester,
  ) async {
    // Arrange
    final e2e = await createShop(tester);
    await signInAndOpenShift(tester, '1234');
    await tapOn(tester, find.text('ไปตั้งค่าโต๊ะ'));

    // Act: package, add-on with a cost, table, supplier, ingredient, cashier.
    await openTab(tester, 'packages');
    await typeIntoField(tester, 'ชื่อแพ็กเกจ *', 'บุฟเฟต์ 399');
    await tapKey(tester, 'pkg-timelimit-preset-120');
    await typeIntoField(tester, 'ราคาผู้ใหญ่ (บาท) *', '399');
    await typeIntoField(tester, 'ราคาเด็ก (บาท) *', '199');
    await save(tester);

    await openTab(tester, 'addons');
    await typeIntoField(tester, 'ชื่อสินค้า *', 'โค้ก');
    await typeIntoField(tester, 'ราคาขาย (บาท) *', '45');
    await typeIntoField(tester, 'ต้นทุนต่อหน่วย (บาท)', '30');
    await typeIntoField(tester, 'จำนวนคงเหลือในสต็อก', '24');
    await save(tester);

    await openTab(tester, 'tables');
    await typeIntoField(tester, 'ชื่อโต๊ะ *', 'A1');
    await save(tester);

    await openTab(tester, 'suppliers');
    await typeIntoField(tester, 'ชื่อแหล่งซื้อ *', 'ตลาดสด');
    await save(tester);

    await openTab(tester, 'ingredients');
    await typeIntoField(tester, 'ชื่อวัตถุดิบ *', 'หมูสามชั้น');
    await typeIntoField(tester, 'ราคาซื้อล่าสุด (บาท/หน่วย)', '180');
    await save(tester);

    await openTab(tester, 'staff');
    await typeIntoField(tester, 'ชื่อพนักงาน *', 'แคชเชียร์ E2E');
    await typeIntoField(tester, 'รหัส PIN (ตัวเลข 4 หลัก) *', '5678');
    await save(tester);

    // Assert: everything reached the server with the right amounts.
    final owner = await ownerClient(e2e.email, e2e.password);
    final shopId = await shopIdOf(owner, e2e);
    final pkg = await owner
        .from('packages')
        .select('name, adult_price, child_price, time_limit_min')
        .eq('shop_id', shopId)
        .single();
    expect(pkg, <String, dynamic>{
      'name': 'บุฟเฟต์ 399',
      'adult_price': 39900,
      'child_price': 19900,
      'time_limit_min': 120,
    });
    final addon = await owner
        .from('addons')
        .select('name, price, stock')
        .eq('shop_id', shopId)
        .single();
    expect(addon, <String, dynamic>{
      'name': 'โค้ก',
      'price': 4500,
      'stock': 24,
    });
    final costs = await owner.rpc<Map<String, dynamic>>(
      'get_manager_data',
      params: <String, dynamic>{
        'p_shop_id': shopId,
        'p_from': '2000-01-01',
        'p_to': '2100-01-01',
      },
    );
    expect(
      (costs['addon_costs'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .single['cost'],
      3000,
    );
    expect(
      (costs['ingredient_costs'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .single['last_cost'],
      18000,
    );
    final tables = await owner
        .from('dining_tables')
        .select('name')
        .eq('shop_id', shopId);
    expect(tables.single['name'], 'A1');
    final suppliers = await owner
        .from('suppliers')
        .select('name')
        .eq('shop_id', shopId);
    expect(suppliers.single['name'], 'ตลาดสด');
    final cashier = await owner
        .from('staff')
        .select('role')
        .eq('shop_id', shopId)
        .eq('name', 'แคชเชียร์ E2E')
        .single();
    expect(cashier['role'], 'cashier');

    // Act: sign out, then try the cashier with a wrong and the right PIN.
    await tapKey(tester, 'shell-menu-btn');
    await tapKey(tester, 'sidebar-logout-btn');
    await waitFor(tester, find.text('เข้าสู่ระบบ'));
    await tapOn(tester, find.text('เจ้าของ E2E'));
    await tapOn(tester, find.text('แคชเชียร์ E2E'));
    await typeOnPad(tester, '0000');
    await waitForServer(tester);

    // Assert
    await waitFor(tester, find.byKey(const ValueKey('login-error')));
    await typeOnPad(tester, '5678');
    await waitForServer(tester);
    await waitFor(tester, find.text('โต๊ะและการขาย'));
    await tapKey(tester, 'shell-menu-btn');
    await waitFor(tester, find.text('แคชเชียร์ E2E'));
  });
}
