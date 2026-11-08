// Runs against a local Supabase stack, like supabase_repository_test.dart.
import 'dart:io';

import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/outbox_queue.dart';
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

void main() {
  final url = Platform.environment['SUPABASE_TEST_URL'];
  final key = Platform.environment['SUPABASE_TEST_ANON_KEY'];
  final skip = url == null || key == null ? 'SUPABASE_TEST_URL not set' : false;

  test(
    'bills made offline sync later with the same numbers',
    skip: skip,
    () async {
      // Arrange: a shop, a paired device on a switchable network, a cashier.
      HttpOverrides.global = null;
      const auth = AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      );
      final net = _Switchable();
      final owner = SupabaseClient(url!, key!, authOptions: auth);
      final device = SupabaseClient(
        url,
        key,
        authOptions: auth,
        httpClient: net,
      );
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
          'p_pairing_code':
              (pairing.first as Map<String, dynamic>)['pairing_code'],
        },
      );
      final cashier = await owner
          .from('staff')
          .insert(<String, dynamic>{
            'shop_id': shopId,
            'name': 'แคชเชียร์',
            'role': 'cashier',
          })
          .select('id')
          .single();
      await owner.rpc<void>(
        'set_staff_pin',
        params: <String, dynamic>{'p_staff_id': cashier['id'], 'p_pin': '1111'},
      );
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
      repo.outbox = OutboxQueue(db, shopId: shopId);
      final me = repo.state.staff.firstWhere((s) => s.id == cashier['id']);
      await repo.signInWithPin(me.id, '1111');
      await repo.openCashShift(staffId: me.id, floatAmount: 100000);
      final cash = repo.state.payments.firstWhere((p) => p.type == 'cash');
      final pkg = repo.state.packages.single;

      Future<void> sell(DiningTable table) => repo.settleOrder(
        table: table,
        cart: TableTotals(a: 2),
        staff: me,
        timing: 'before',
        packageId: pkg.id,
        method: cash,
        received: 59800,
        billId: repo.newBillId(DateTime.now()),
        notes: '',
      );

      // Act: the internet drops, two tables pay.
      net.down = true;
      await sell(repo.state.tables[0]);
      await sell(repo.state.tables[1]);

      // Assert: sold on the device with its own receipt numbers, queued.
      expect(repo.state.sales.map((b) => b.no), <String>[
        '00000-POS01-000001',
        '00000-POS01-000002',
      ]);
      expect(repo.state.sales.every((b) => b.total == 59800), isTrue);
      expect(await repo.outbox!.pendingCount(), 2);

      // Act: the internet is back.
      net.down = false;
      final result = await repo.flushOutbox();

      // Assert: the server keeps both bills with the same numbers and totals.
      expect(result!.sent, 2);
      expect(result.rejected, 0);
      expect(await repo.outbox!.pendingCount(), 0);
      final bills = await owner
          .from('bills')
          .select('no, total')
          .eq('shop_id', shopId)
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
}
