// Runs against a local Supabase stack, like supabase_repository_test.dart.
import 'dart:io';

import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/offline_credentials.dart';
import 'package:app/core/data/local/outbox_queue.dart';
import 'package:app/core/data/local/shop_snapshot_store.dart';
import 'package:app/core/data/supabase/supabase_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// An HTTP client whose network can be switched off, as when a shop's
/// internet drops.
class _Switchable extends http.BaseClient {
  final http.Client _inner = http.Client();
  bool down = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (down) throw http.ClientException('network is down', request.url);
    return _inner.send(request);
  }
}

/// A paired device on a switchable network, a cashier (PIN 1111), a manager
/// (PIN 2222), two tables and one package.
class _Shop {
  new(this.owner, this.net, this.repo, this.id, this.db, this.device);

  final SupabaseClient owner;
  final _Switchable net;
  final SupabasePosRepository repo;
  final String id;
  final LocalDb db;
  final SupabaseClient device;

  StaffMember staff(String role) =>
      repo.state.staff.firstWhere((s) => s.role == role);

  Future<String> sell(StaffMember me, DiningTable table) async {
    final billId = repo.newBillId(DateTime.now());
    await repo.settleOrder(
      table: table,
      cart: TableTotals(a: 2),
      staff: me,
      timing: 'before',
      packageId: repo.state.packages.single.id,
      method: repo.state.payments.firstWhere((p) => p.type == 'cash'),
      received: 59800,
      billId: billId,
      notes: '',
    );
    return billId;
  }
}

Future<_Shop> _openShop(String url, String key) async {
  HttpOverrides.global = null;
  const auth = AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  );
  final net = _Switchable();
  final owner = SupabaseClient(url, key, authOptions: auth);
  final device = SupabaseClient(url, key, authOptions: auth, httpClient: net);
  await owner.auth.signUp(
    email: 'off-${DateTime.now().microsecondsSinceEpoch}@example.test',
    password: 'integration-pass-1',
  );
  final shopId = await owner.rpc<String>(
    'create_organization_with_shop',
    params: <String, dynamic>{
      'p_org_name': 'ออฟไลน์',
      'p_shop_name': 'ออฟไลน์',
    },
  );
  final pairing = await owner.rpc<List<dynamic>>(
    'create_device_pairing',
    params: <String, dynamic>{'p_shop_id': shopId, 'p_name': 'เครื่อง 1'},
  );
  await device.auth.signInAnonymously();
  await device.rpc<List<dynamic>>(
    'claim_device',
    params: <String, dynamic>{
      'p_pairing_code': (pairing.first as Map<String, dynamic>)['pairing_code'],
    },
  );
  for (final (name, role, pin) in <(String, String, String)>[
    ('แคชเชียร์', 'cashier', '1111'),
    ('ผู้จัดการ', 'manager', '2222'),
  ]) {
    final row = await owner
        .from('staff')
        .insert(<String, dynamic>{
          'shop_id': shopId,
          'name': name,
          'role': role,
        })
        .select('id')
        .single();
    await owner.rpc<void>(
      'set_staff_pin',
      params: <String, dynamic>{'p_staff_id': row['id'], 'p_pin': pin},
    );
  }
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
  final repo = await SupabasePosRepository.open(
    deviceClient: device,
    shopId: shopId,
    deviceUserId: device.auth.currentUser!.id,
  );
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  repo
    ..outbox = OutboxQueue(db, shopId: shopId)
    // The VM has no Web Crypto; a plain hash is enough to compare PINs here.
    ..credentials = OfflineCredentials(
      db,
      shopId: shopId,
      hash: (pin, salt) async => '$salt:$pin',
    );
  return _Shop(owner, net, repo, shopId, db, device);
}

void main() {
  final url = Platform.environment['SUPABASE_TEST_URL'];
  final key = Platform.environment['SUPABASE_TEST_ANON_KEY'];
  final skip = url == null || key == null ? 'SUPABASE_TEST_URL not set' : false;

  test(
    'bills made offline sync later with the same numbers',
    skip: skip,
    () async {
      // Arrange
      final shop = await _openShop(url!, key!);
      final repo = shop.repo;
      final me = shop.staff('cashier');
      await repo.signInWithPin(me.id, '1111');
      await repo.openCashShift(staffId: me.id, floatAmount: 100000);

      // Act: the internet drops, two tables pay.
      shop.net.down = true;
      await shop.sell(me, repo.state.tables[0]);
      await shop.sell(me, repo.state.tables[1]);

      // Assert: sold on the device with its own receipt numbers, queued.
      expect(repo.state.sales.map((b) => b.no), <String>[
        '00000-POS01-000001',
        '00000-POS01-000002',
      ]);
      expect(repo.state.sales.every((b) => b.total == 59800), isTrue);
      expect(await repo.outbox!.pendingCount(), 2);

      // Act: the internet is back.
      shop.net.down = false;
      final result = await repo.flushOutbox();

      // Assert: the server keeps both bills with the same numbers and totals.
      expect(result!.sent, 2);
      expect(result.rejected, 0);
      expect(await repo.outbox!.pendingCount(), 0);
      final bills = await shop.owner
          .from('bills')
          .select('no, total')
          .eq('shop_id', shop.id)
          .order('no', ascending: true);
      expect(bills, <Map<String, dynamic>>[
        <String, dynamic>{'no': '00000-POS01-000001', 'total': 59800},
        <String, dynamic>{'no': '00000-POS01-000002', 'total': 59800},
      ]);
      expect(repo.state.sales.map((b) => b.no).toList()..sort(), <String>[
        '00000-POS01-000001',
        '00000-POS01-000002',
      ]);
    },
  );

  test(
    'a sale queued by one person survives another sign-in; offline PIN; '
    'manager voids offline',
    skip: skip,
    () async {
      // Arrange: the manager opens the shift, the cashier signs in online.
      final shop = await _openShop(url!, key!);
      final repo = shop.repo;
      final cashier = shop.staff('cashier');
      final manager = shop.staff('manager');
      await repo.signInWithPin(manager.id, '2222');
      await repo.openCashShift(staffId: manager.id, floatAmount: 100000);
      await repo.signInWithPin(cashier.id, '1111');

      // Act: the internet drops while the cashier sells.
      shop.net.down = true;
      final billId = await shop.sell(cashier, repo.state.tables.first);

      // Act: back online, the manager signs in before the queue is sent,
      // which ends the cashier's session on this device.
      shop.net.down = false;
      expect(
        await repo.signInWithPin(manager.id, '2222'),
        PinSignInResult.success,
      );
      final first = await repo.flushOutbox();

      // Assert: the cashier's sale still went through.
      expect(first!.rejected, 0);
      expect(first.sent, 1);

      // Act & Assert: offline, PINs are checked on the device.
      shop.net.down = true;
      await repo.signOutStaff();
      expect(
        await repo.signInWithPin(manager.id, '0000'),
        PinSignInResult.invalid,
      );
      expect(
        await repo.signInWithPin(manager.id, '2222'),
        PinSignInResult.success,
      );

      // Act: still offline, the manager voids the bill.
      expect(
        await repo.voidSale(billId: billId, staff: manager, reason: 'ทดสอบ'),
        isTrue,
      );
      expect(repo.state.sales.single.voided, isTrue);
      shop.net.down = false;
      final second = await repo.flushOutbox();

      // Assert: the server has the bill, voided.
      expect(second!.sent, 1);
      expect(second.rejected, 0);
      final bill = await shop.owner
          .from('bills')
          .select('voided')
          .eq('id', billId)
          .single();
      expect(bill['voided'], isTrue);
    },
  );

  test(
    'restarting offline continues from the saved shop',
    skip: skip,
    () async {
      // Arrange: a costed add-on; a manager who sees costs; one online sale.
      final shop = await _openShop(url!, key!);
      await shop.owner.from('addons').insert(<String, dynamic>{
        'shop_id': shop.id,
        'name': 'โค้ก',
        'category': 'เครื่องดื่ม',
        'price': 4500,
        'cost': 3000,
        'stock': 24,
      });
      await shop.owner
          .from('staff')
          .update(<String, dynamic>{'can_view_costs': true})
          .eq('shop_id', shop.id)
          .eq('role', 'manager');
      final repo = shop.repo;
      final cashier = shop.staff('cashier');
      final manager = shop.staff('manager');
      await repo.signInWithPin(cashier.id, '1111');
      await repo.signInWithPin(manager.id, '2222');
      await repo.openCashShift(staffId: manager.id, floatAmount: 100000);
      await shop.sell(manager, repo.state.tables[0]);
      expect(repo.state.addons.single.cost, 3000);

      // Act: offline, one more sale, and the shop is saved as the app does.
      shop.net.down = true;
      await shop.sell(manager, repo.state.tables[1]);
      final store = ShopSnapshotStore(shop.db);
      await store.save(shop.id, repo.toSnapshot());

      // Assert: what is kept on the device has no cost.
      final saved = (await store.latest())!;
      final addons = (saved.data['state'] as Map)['addons'] as List<dynamic>;
      expect((addons.single as Map)['cost'], 0);

      // Act: the app restarts, still offline, from the saved shop.
      final queue = OutboxQueue(shop.db, shopId: shop.id);
      final restarted =
          SupabasePosRepository.restore(
              deviceClient: shop.device,
              shopId: saved.shopId,
              data: saved.data,
            )
            ..outbox = queue
            ..credentials = shop.repo.credentials;
      final queued = await queue.maxPendingInt('p_seq');
      if (queued > restarted.receiptSeq) restarted.receiptSeq = queued;
      expect(
        await restarted.signInWithPin(cashier.id, '1111'),
        PinSignInResult.success,
      );
      final again = _Shop(
        shop.owner,
        shop.net,
        restarted,
        shop.id,
        shop.db,
        shop.device,
      );
      await again.sell(cashier, restarted.state.tables[0]);

      // Assert: earlier sales are there and numbering continues.
      expect(restarted.state.sales.map((b) => b.no).toList()..sort(), <String>[
        '00000-POS01-000001',
        '00000-POS01-000002',
        '00000-POS01-000003',
      ]);
      expect(restarted.canReadCosts, isFalse);

      // Act: the internet is back.
      shop.net.down = false;
      final result = await restarted.flushOutbox();

      // Assert: the server has all three bills.
      expect(result!.rejected, 0);
      expect(result.sent, 2);
      final bills = await shop.owner
          .from('bills')
          .select('no')
          .eq('shop_id', shop.id)
          .order('no', ascending: true);
      expect(bills.map((b) => b['no']), <String>[
        '00000-POS01-000001',
        '00000-POS01-000002',
        '00000-POS01-000003',
      ]);
    },
  );
}
