// Runs against a local Supabase stack (same as offline_sync_test.dart):
//   SUPABASE_TEST_URL=... SUPABASE_TEST_ANON_KEY=... \
//   flutter test --no-pub test/integration/realtime_two_devices_test.dart
import 'dart:async';
import 'dart:io';

import 'package:app/core/data/supabase/supabase_pos_repository.dart';
import 'package:app/core/sync/realtime_sync.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _auth = AuthClientOptions(
  autoRefreshToken: false,
  authFlowType: AuthFlowType.implicit,
);

/// A paired device: its own client built with `accessToken`, like the app's.
class _Device {
  new(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
}

Future<_Device> _pair(
  String url,
  String key,
  SupabaseClient owner,
  String shopId,
) async {
  final pairing = await owner.rpc<List<dynamic>>(
    'create_device_pairing',
    params: <String, dynamic>{'p_shop_id': shopId, 'p_name': 'เครื่อง'},
  );
  final anon = SupabaseClient(url, key, authOptions: _auth);
  await anon.auth.signInAnonymously();
  await anon.rpc<List<dynamic>>(
    'claim_device',
    params: <String, dynamic>{
      'p_pairing_code': (pairing.first as Map<String, dynamic>)['pairing_code'],
    },
  );
  final jwt = anon.auth.currentSession!.accessToken;
  final client = SupabaseClient(url, key, accessToken: () async => jwt);
  return _Device(client, anon.auth.currentUser!.id);
}

Future<String> _newShop(SupabaseClient owner, {required bool staff}) async {
  await owner.auth.signUp(
    email: 'rt-${DateTime.now().microsecondsSinceEpoch}@example.test',
    password: 'integration-pass-1',
  );
  final shopId = await owner.rpc<String>(
    'create_organization_with_shop',
    params: <String, dynamic>{
      'p_org_name': 'เรียลไทม์',
      'p_shop_name': 'เรียลไทม์',
    },
  );
  if (!staff) return shopId;
  final row = await owner
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
    params: <String, dynamic>{'p_staff_id': row['id'], 'p_pin': '1111'},
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
  return shopId;
}

Future<void> _sell(
  SupabasePosRepository repo,
  StaffMember me,
  int tableIdx,
) async {
  await repo.settleOrder(
    table: repo.state.tables[tableIdx],
    cart: TableTotals(a: 2),
    staff: me,
    timing: 'before',
    packageId: repo.state.packages.single.id,
    method: repo.state.payments.firstWhere((p) => p.type == 'cash'),
    received: 59800,
    billId: repo.newBillId(DateTime.now()),
    notes: '',
  );
}

void main() {
  final url = Platform.environment['SUPABASE_TEST_URL'];
  final key = Platform.environment['SUPABASE_TEST_ANON_KEY'];
  final skip = url == null || key == null ? 'SUPABASE_TEST_URL not set' : false;

  test('a sale on one device signals the shop siblings, not other shops', skip: skip, () async {
    HttpOverrides.global = null;
    final owner1 = SupabaseClient(url!, key!, authOptions: _auth);
    final owner2 = SupabaseClient(url, key, authOptions: _auth);
    final shop1 = await _newShop(owner1, staff: true);
    final shop2 = await _newShop(owner2, staff: false);
    final a = await _pair(url, key, owner1, shop1);
    final b = await _pair(url, key, owner1, shop1);
    final c = await _pair(url, key, owner2, shop2);

    Future<SupabasePosRepository> openRepo(_Device d) =>
        SupabasePosRepository.open(
          deviceClient: d.client,
          shopId: shop1,
          deviceUserId: d.userId,
        );
    final repoA = await openRepo(a);
    final cashier = repoA.state.staff.single;
    await repoA.signInWithPin(cashier.id, '1111');
    await repoA.openCashShift(staffId: cashier.id, floatAmount: 100000);
    final repoB = await openRepo(b);
    await repoB.signInWithPin(cashier.id, '1111');

    var aHits = 0, bHits = 0, cOwnHits = 0, cRawHits = 0;
    final clock = Stopwatch();
    Completer<void> bGot = Completer<void>(), aGot = Completer<void>();
    final syncA = RealtimeSync.shop(a.client, shop1, () async {
      aHits++;
      if (!aGot.isCompleted) aGot.complete();
    });
    final syncB = RealtimeSync.shop(b.client, shop1, () async {
      bHits++;
      if (!bGot.isCompleted) bGot.complete();
    });
    final syncC = RealtimeSync.shop(c.client, shop2, () async => cOwnHits++);
    await c.client.realtime.setAuth(null);
    final rawC = c.client
        .channel(
          'shop:$shop1',
          opts: const RealtimeChannelConfig(private: true),
        )
        .onBroadcast(event: 'changed', callback: (_) => cRawHits++);
    final rawStatus = Completer<RealtimeSubscribeStatus>();
    rawC.subscribe((s, e) {
      if (!rawStatus.isCompleted) rawStatus.complete(s);
    });
    debugPrint(
      'raw private channel on C -> shop1: ${await rawStatus.future.timeout(const Duration(seconds: 8), onTimeout: () => RealtimeSubscribeStatus.timedOut)}',
    );
    await Future<void>.delayed(const Duration(seconds: 3)); // let B/A subscribe

    // A writes -> B fires, C silent.
    clock.start();
    await _sell(repoA, cashier, 0);
    await bGot.future.timeout(const Duration(seconds: 5));
    final ab = clock.elapsedMilliseconds;
    debugPrint('A->B latency incl. RPC + 500ms debounce: ${ab}ms');
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(cOwnHits, 0);
    expect(cRawHits, 0);

    // B writes -> A fires.
    final aBefore = aHits;
    aGot = Completer<void>();
    clock
      ..reset()
      ..start();
    await _sell(repoB, cashier, 1);
    await aGot.future.timeout(const Duration(seconds: 5));
    debugPrint(
      'B->A latency incl. RPC + 500ms debounce: ${clock.elapsedMilliseconds}ms '
      '(A hits ${aHits - aBefore}, B hits $bHits, C own $cOwnHits, C raw $cRawHits)',
    );
    expect(cRawHits, 0);
    expect(cOwnHits, 0);

    syncA.dispose();
    syncB.dispose();
    syncC.dispose();
    await c.client.removeChannel(rawC);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
