// Runs against a local Supabase stack:
//   SUPABASE_TEST_URL=... SUPABASE_TEST_ANON_KEY=... \
//   flutter test --no-pub test/integration/supabase_repository_test.dart
import 'dart:io';

import 'package:app/core/data/supabase/supabase_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final url = Platform.environment['SUPABASE_TEST_URL'];
  final key = Platform.environment['SUPABASE_TEST_ANON_KEY'];
  final skip = url == null || key == null ? 'SUPABASE_TEST_URL not set' : false;

  group('SupabasePosRepository', skip: skip, () {
    late SupabaseClient owner;
    late SupabaseClient device;
    late SupabasePosRepository repo;
    late String shopId;
    late String cashierId;
    late String managerId;

    SupabaseClient client() => SupabaseClient(
      url!,
      key!,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );

    setUpAll(() async {
      // flutter test blocks real HTTP; this test targets a local stack.
      HttpOverrides.global = null;
      // Arrange: owner signs up and creates a shop through the real API.
      owner = client();
      await owner.auth.signUp(
        email: 'it-${DateTime.now().microsecondsSinceEpoch}@example.test',
        password: 'integration-pass-1',
      );
      shopId = await owner.rpc<String>(
        'create_organization_with_shop',
        params: <String, dynamic>{
          'p_org_name': 'ร้านทดสอบรวม',
          'p_shop_name': 'สาขาทดสอบ',
        },
      );
      final pairing = await owner.rpc<List<dynamic>>(
        'create_device_pairing',
        params: <String, dynamic>{'p_shop_id': shopId, 'p_name': 'เครื่อง 1'},
      );
      device = client();
      await device.auth.signInAnonymously();
      await device.rpc<List<dynamic>>(
        'claim_device',
        params: <String, dynamic>{
          'p_pairing_code':
              (pairing.first as Map<String, dynamic>)['pairing_code'],
        },
      );

      Future<String> addStaff(String name, String role, String pin) async {
        final row = await owner
            .from('staff')
            .insert(<String, dynamic>{
              'shop_id': shopId,
              'name': name,
              'role': role,
            })
            .select('id')
            .single();
        final id = row['id'] as String;
        await owner.rpc<void>(
          'set_staff_pin',
          params: <String, dynamic>{'p_staff_id': id, 'p_pin': pin},
        );
        return id;
      }

      cashierId = await addStaff('แคชเชียร์', 'cashier', '1111');
      managerId = await addStaff('ผู้จัดการ', 'manager', '2222');
      await owner.from('dining_tables').insert(<Map<String, dynamic>>[
        <String, dynamic>{'shop_id': shopId, 'name': 'A1', 'seats': 4},
        <String, dynamic>{'shop_id': shopId, 'name': 'A2', 'seats': 4},
      ]);
      await owner.from('packages').insert(<String, dynamic>{
        'shop_id': shopId,
        'name': 'บุฟเฟต์',
        'adult_price': 29900,
        'child_price': 14900,
      });
      await owner.from('addons').insert(<String, dynamic>{
        'shop_id': shopId,
        'name': 'น้ำ',
        'price': 2050,
        'cost': 800,
        'stock': 10,
      });
      repo = await SupabasePosRepository.open(
        deviceClient: device,
        ownerClient: owner,
        shopId: shopId,
      );
    });

    StaffMember staffOf(String id) =>
        repo.state.staff.firstWhere((s) => s.id == id);

    test('loads the shop without PINs or cost data before sign-in', () {
      // Assert
      expect(repo.isDemoData, isFalse);
      expect(repo.canReadCosts, isFalse);
      expect(repo.state.shop.name, 'สาขาทดสอบ');
      expect(repo.state.staff.every((s) => s.pin.isEmpty), isTrue);
      expect(repo.state.addons.single.cost, 0);
      expect(repo.state.addons.single.price, 2050);
      expect(repo.state.expenseTypes.length, 7);
    });

    test(
      'wrong PIN is rejected; commands need a signed-in staff member',
      () async {
        // Act
        final result = await repo.signInWithPin(cashierId, '0000');

        // Assert
        expect(result, PinSignInResult.invalid);
        expect(repo.currentStaff, isNull);
        await expectLater(
          repo.closeTable('none'),
          completes,
          reason: 'no open session means nothing to do',
        );
        await expectLater(
          repo.openCashShift(staffId: cashierId, floatAmount: 100000),
          throwsA(isA<PosCommandException>()),
        );
      },
    );

    test(
      'cashier sale: domain total matches the server to the satang',
      () async {
        // Arrange
        expect(
          await repo.signInWithPin(cashierId, '1111'),
          PinSignInResult.success,
        );
        expect(repo.canReadCosts, isFalse);
        await repo.openCashShift(staffId: cashierId, floatAmount: 100000);
        final table = repo.state.tables.first;
        final pkg = repo.state.packages.first;
        final addon = repo.state.addons.first;
        final cash = repo.state.payments.firstWhere((p) => p.type == 'cash');
        final cart = TableTotals(a: 2, c: 1, ad: <String, int>{addon.id: 1});

        // Act
        final billId = repo.newBillId(DateTime.now());
        await repo.settleOrder(
          table: table,
          cart: cart,
          staff: staffOf(cashierId),
          timing: 'before',
          packageId: pkg.id,
          method: cash,
          received: 100000,
          billId: billId,
          notes: '',
        );

        // Assert: 2*299 + 149 + 20.50 = 767.50, rounded down to 767
        final bill = repo.state.sales.single;
        expect(bill.id, billId);
        expect(bill.subtotal, 76750);
        expect(bill.rounding, -50);
        expect(bill.total, 76700);
        expect(bill.change, 100000 - 76700);
        expect(bill.no, '00000-POS01-000001');
        expect(bill.staffName, 'แคชเชียร์');
        expect(repo.state.addons.first.stock, 9);
        expect(repo.state.openTables[table.id]?.billIds, <String>[billId]);
        expect(openShiftOf(repo.state), isNotNull);
      },
    );

    test(
      'eat-before-paying: rounds, reduction by manager, then settle',
      () async {
        // Arrange
        final table = repo.state.tables.last;
        final pkg = repo.state.packages.first;
        final addon = repo.state.addons.first;
        final qr = repo.state.payments.firstWhere((p) => p.type == 'qr');

        // Act
        await repo.sendOrderRound(
          table: table,
          cart: TableTotals(a: 3, ad: <String, int>{addon.id: 2}),
          staff: staffOf(cashierId),
          timing: 'after',
          packageId: pkg.id,
          notes: 'ไม่ใส่ผัก',
        );
        final dueBefore = tableDue(
          repo.state,
          repo.state.openTables[table.id]!,
        );

        // Assert: a cashier cannot reduce, and the failure carries a message.
        await expectLater(
          repo.adjustSentItem(
            tableId: table.id,
            kind: 'head',
            key: 'a',
            qty: 1,
            reason: 'ไม่ควรผ่าน',
            staff: staffOf(cashierId),
          ),
          throwsA(isA<PosCommandException>()),
        );
        await expectLater(
          repo.closeTable(table.id),
          throwsA(isA<PosCommandException>()),
        );
        expect(dueBefore, 3 * 29900 + 2 * 2050);

        // Act: manager reduces one head and settles.
        await repo.signOutStaff();
        expect(
          await repo.signInWithPin(managerId, '2222'),
          PinSignInResult.success,
        );
        expect(repo.canReadCosts, isTrue);
        expect(repo.state.addons.first.cost, 800);
        await repo.adjustSentItem(
          tableId: table.id,
          kind: 'head',
          key: 'a',
          qty: 1,
          reason: 'คีย์ผิด',
          staff: staffOf(managerId),
        );
        final open = repo.state.openTables[table.id]!;
        expect(open.notes, 'ไม่ใส่ผัก');
        expect(open.adjusts.single.qty, -1);
        expect(tableDue(repo.state, open), 2 * 29900 + 2 * 2050);

        await repo.settleOrder(
          table: table,
          cart: TableTotals(),
          staff: staffOf(managerId),
          timing: 'after',
          packageId: pkg.id,
          method: qr,
          received: 0,
          billId: repo.newBillId(DateTime.now()),
          notes: '',
        );

        // Assert
        final bill = repo.state.sales.last;
        expect(bill.total, 2 * 29900 + 2 * 2050);
        expect(bill.received, bill.total);
        expect(bill.lines.last.cost, 800);
        final after = repo.state.openTables[table.id]!;
        expect(after.rounds, isEmpty);
        expect(after.adjusts, isEmpty);
        expect(tableDue(repo.state, after), 0);
        await repo.closeTable(table.id);
        expect(repo.state.openTables.containsKey(table.id), isFalse);
      },
    );

    test(
      'manager records an expense; cashier sees it without the amount',
      () async {
        // Arrange
        final type = repo.state.expenseTypes.first;
        final manager = staffOf(managerId);
        final now = DateTime.now();
        final today = businessDayKey(now, repo.state.shop.dayCutoffMinutes);

        // Act
        expect(
          await repo.recordExpenses(
            date: today,
            lines: <ExpenseDraftLine>[
              ExpenseDraftLine(typeId: type.id, amount: 45050, note: 'น้ำแข็ง'),
            ],
            staff: manager,
            now: now,
          ),
          isTrue,
        );

        // Assert
        expect(repo.state.expenses.single.amount, 45050);
        await repo.signOutStaff();
        expect(repo.canReadCosts, isFalse);
        expect(repo.state.expenses, isEmpty);
        expect(
          await repo.signInWithPin(cashierId, '1111'),
          PinSignInResult.success,
        );
        final seen = repo.state.expenses.single;
        expect(seen.note, 'น้ำแข็ง');
        expect(seen.amount, 0);
        expect(repo.canReadCosts, isFalse);
        expect(repo.state.sales.last.lines.last.cost, isNull);
      },
    );

    test(
      'voiding restores stock; cashier cannot void from the bills page',
      () async {
        // Arrange
        final sale = repo.state.sales.first;
        final stockBefore = repo.state.addons.first.stock;
        final cashier = staffOf(cashierId);

        // Act & Assert
        expect(
          await repo.voidSale(billId: sale.id, staff: cashier, reason: 'x'),
          isFalse,
        );
        expect(
          await repo.voidSale(
            billId: sale.id,
            staff: cashier,
            reason: 'ลูกค้าเปลี่ยนใจ',
            allowCashier: true,
          ),
          isTrue,
        );
        expect(repo.state.sales.first.voided, isTrue);
        expect(repo.state.addons.first.stock, stockBefore + 1);
        final table = repo.state.tables.first;
        expect(repo.state.openTables.containsKey(table.id), isFalse);
      },
    );

    test('setup needs the owner login and keeps a blank PIN', () async {
      // Arrange: a device session with no owner login cannot edit the catalog.
      final noOwner = await SupabasePosRepository.open(
        deviceClient: device,
        shopId: shopId,
      );
      const newItem = SupplierItem(id: 'sup123', name: 'ตลาดเช้า');

      // Act
      final denied = await noOwner.saveSupplier(newItem);
      final saved = await repo.saveSupplier(newItem);
      final renamed = await repo.saveStaffMember(
        staffOf(cashierId).copyWith(name: 'แคชเชียร์ใหม่'),
        actorRole: 'owner',
      );
      final badPin = await repo.saveStaffMember(
        staffOf(cashierId).copyWith(pin: '12'),
        actorRole: 'owner',
      );

      // Assert
      expect(denied.ok, isFalse);
      expect(saved.ok, isTrue);
      expect(repo.state.suppliers.single.name, 'ตลาดเช้า');
      expect(repo.state.suppliers.single.id, isNot('sup123'));
      expect(renamed.ok, isTrue);
      expect(staffOf(cashierId).name, 'แคชเชียร์ใหม่');
      expect(badPin.ok, isFalse);
      await repo.signOutStaff();
      expect(
        await repo.signInWithPin(cashierId, '1111'),
        PinSignInResult.success,
      );
    });

    test(
      'the owner adds and edits add-ons and ingredients with costs',
      () async {
        // Arrange: a manager session can read costs back.
        await repo.signOutStaff();
        expect(
          await repo.signInWithPin(managerId, '2222'),
          PinSignInResult.success,
        );
        final addon = AddonItem(
          id: 'ad-new',
          name: 'โค้ก 1.25 ลิตร',
          category: 'เครื่องดื่ม',
          price: 4500,
          cost: 3000,
          stock: 24,
        );
        const ingredient = IngredientItem(
          id: 'ing-new',
          name: 'หมูสามชั้น',
          unit: 'กก.',
          lastCost: 18000,
          par: 5,
          supplierId: '',
          category: 'เนื้อสัตว์',
          use: 0.2,
        );

        // Act
        final addedAddon = await repo.saveAddon(addon);
        final addedIngredient = await repo.saveIngredient(ingredient);
        final savedAddon = repo.state.addons.firstWhere(
          (x) => x.name == 'โค้ก 1.25 ลิตร',
        );
        final savedIngredient = repo.state.ingredients.firstWhere(
          (x) => x.name == 'หมูสามชั้น',
        );
        final editedAddon = await repo.saveAddon(
          savedAddon.copyWith(price: 5000, cost: 3200),
        );
        final editedIngredient = await repo.saveIngredient(
          savedIngredient.copyWith(lastCost: 19000),
        );

        // Assert
        expect(addedAddon.ok, isTrue, reason: addedAddon.message);
        expect(addedIngredient.ok, isTrue, reason: addedIngredient.message);
        expect(editedAddon.ok, isTrue, reason: editedAddon.message);
        expect(editedIngredient.ok, isTrue, reason: editedIngredient.message);
        final addonNow = repo.state.addons.where((x) => x.id == savedAddon.id);
        expect(addonNow.single.price, 5000);
        expect(addonNow.single.cost, 3200);
        final ingredientNow = repo.state.ingredients.where(
          (x) => x.id == savedIngredient.id,
        );
        expect(ingredientNow.single.lastCost, 19000);
      },
    );

    test('demo tools and JSON transfer are refused on real data', () async {
      // Act & Assert
      expect((await repo.resetDemoData(DateTime.now())).ok, isFalse);
      expect((await repo.clearDailyData(DateTime.now())).ok, isFalse);
      expect((await repo.advanceSimulationDay()).ok, isFalse);
      expect(repo.exportStateJson, throwsA(isA<PosCommandException>()));
    });
  });
}
