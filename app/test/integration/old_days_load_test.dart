// Runs against a local Supabase stack (and its Docker db container, to seed
// back-dated bills the app cannot create):
//   SUPABASE_TEST_URL=... SUPABASE_TEST_ANON_KEY=... \
//   flutter test --no-pub test/integration/old_days_load_test.dart
import 'dart:io';

import 'package:app/core/data/supabase/supabase_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  final url = Platform.environment['SUPABASE_TEST_URL'];
  final key = Platform.environment['SUPABASE_TEST_ANON_KEY'];
  final skip = url == null || key == null ? 'SUPABASE_TEST_URL not set' : false;
  final dbContainer =
      Platform.environment['SUPABASE_TEST_DB_CONTAINER'] ??
      'supabase_db_keptoh-pos';

  group('days older than the raw window', skip: skip, () {
    late SupabaseClient owner;
    late SupabasePosRepository repo;
    late String shopId;
    late String ownerStaffId;
    late String cashierId;
    late String rawFrom;
    late String oldDay;
    late String recentDay;
    final oldBillId = const Uuid().v4();
    final recentBillId = const Uuid().v4();

    SupabaseClient client() => SupabaseClient(
      url!,
      key!,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );

    void sql(String statement) {
      final r = Process.runSync('docker', <String>[
        'exec',
        dbContainer,
        'psql',
        '-U',
        'postgres',
        '-v',
        'ON_ERROR_STOP=1',
        '-c',
        statement,
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
    }

    setUpAll(() async {
      HttpOverrides.global = null;
      owner = client();
      await owner.auth.signUp(
        email: 'old-${DateTime.now().microsecondsSinceEpoch}@example.test',
        password: 'integration-pass-1',
      );
      shopId = await owner.rpc<String>(
        'create_organization_with_shop',
        params: <String, dynamic>{
          'p_org_name': 'ร้านวันเก่า',
          'p_shop_name': 'สาขาวันเก่า',
        },
      );
      final pairing = await owner.rpc<List<dynamic>>(
        'create_device_pairing',
        params: <String, dynamic>{'p_shop_id': shopId, 'p_name': 'เครื่อง 1'},
      );
      final device = client();
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

      ownerStaffId = await addStaff('เจ้าของ', 'owner', '9999');
      cashierId = await addStaff('แคชเชียร์', 'cashier', '1111');
      repo = await SupabasePosRepository.open(
        deviceClient: device,
        ownerClient: owner,
        shopId: shopId,
      );
      rawFrom = repo.state.rawFrom!;
      oldDay = dkey(addDays(parseKey(rawFrom), -14));
      recentDay = dkey(addDays(parseKey(rawFrom), 2));

      // Seed: the shop opened 40 days before rawFrom; one bill on an old day
      // (with a buffet and an add-on line) and one inside the raw window.
      sql('''
        set session_replication_role = replica;
        update shops set created_at = '${dkey(addDays(parseKey(rawFrom), -40))} 08:00+00'
          where id = '$shopId';
        insert into bills (id, shop_id, device_id, no, business_date, at,
            subtotal, service, vat, total, heads_a, heads_c, heads_f,
            method_type, received, voided)
          select v.id::uuid, d.shop_id, d.id, v.no, v.bd::date,
                 (v.bd || ' 12:00+00')::timestamptz, v.sub, v.svc, v.vat,
                 v.tot, v.ha, v.hc, 0, 'cash', v.tot, false
          from devices d, (values
            ('$oldBillId', 'OLD-1', '$oldDay', 30000, 3000, 2310, 35310, 2, 1),
            ('$recentBillId', 'NEW-1', '$recentDay', 10000, 0, 0, 10000, 1, 0)
          ) as v(id, no, bd, sub, svc, vat, tot, ha, hc)
          where d.shop_id = '$shopId';
        insert into bill_lines (shop_id, bill_id, line_no, type, name, qty, price, cost)
        values
          ('$shopId', '$oldBillId', 1, 'buffet', 'บุฟเฟต์', 2, 10000, null),
          ('$shopId', '$oldBillId', 2, 'addon', 'น้ำ', 2, 5000, 2000),
          ('$shopId', '$recentBillId', 1, 'buffet', 'บุฟเฟต์', 1, 10000, null);
      ''');
    });

    test(
      'owner loads raw bills only from rawFrom; old days as totals',
      () async {
        expect(
          await repo.signInWithPin(ownerStaffId, '9999'),
          PinSignInResult.success,
        );
        final s = await repo.reload();

        expect(s.startDate, dkey(addDays(parseKey(rawFrom), -40)));
        expect(s.sales.map((b) => b.id), <String>[recentBillId]);
        expect(s.sales.every((b) => b.date.compareTo(rawFrom) >= 0), isTrue);

        final t = s.dailyTotals[oldDay]!;
        expect(t.bills, 1);
        expect(t.gross, 35310);
        expect(t.net, 33000);
        expect(t.addonCost, 4000);
        expect(s.dailyTotals.containsKey(recentDay), isFalse);

        final addon = s.addonSalesBefore.singleWhere((a) => a.date == oldDay);
        expect(addon.name, 'น้ำ');
        expect(addon.qty, 2);
        expect(addon.rev, 10000);
        expect(addon.cost, 4000);

        final day = computeLedger(s).byDate[oldDay]!;
        expect(day.bills, 1);
        expect(day.gross, 35310);
        expect(day.net, 33000);
        expect(day.buffetNet, closeTo(22000, 0.001));
        expect(day.addonNet, closeTo(11000, 0.001));
        expect(day.addonCost, 4000);
        expect(computeLedger(s).byDate[recentDay]!.bills, 1);
      },
    );

    test(
      'billsForDay fetches an old day with line costs for the owner',
      () async {
        final bills = await repo.billsForDay(oldDay);

        expect(bills.map((b) => b.id), <String>[oldBillId]);
        expect(bills.single.total, 35310);
        expect(
          bills.single.lines.map((l) => (l.type, l.qty, l.cost)),
          <(String, int, int?)>[('buffet', 2, null), ('addon', 2, 2000)],
        );
        expect(await repo.billsForDay(recentDay), hasLength(1));
        expect(await repo.billsForDay('2000-01-01'), isEmpty);
      },
    );

    test('a cashier gets no add-on costs, in totals or in old bills', () async {
      await repo.signOutStaff();
      expect(
        await repo.signInWithPin(cashierId, '1111'),
        PinSignInResult.success,
      );
      final s = await repo.reload();

      expect(repo.canReadCosts, isFalse);
      expect(s.sales.map((b) => b.id), <String>[recentBillId]);
      expect(s.dailyTotals[oldDay]!.gross, 35310);
      expect(s.dailyTotals[oldDay]!.addonCost, isNull);
      final addon = s.addonSalesBefore.singleWhere((a) => a.date == oldDay);
      expect(addon.rev, 10000);
      expect(addon.cost, isNull);

      final bills = await repo.billsForDay(oldDay);
      expect(bills.single.lines.every((l) => l.cost == null), isTrue);
    });
  });
}
