// Runs against a local Supabase stack (and its Docker db container, to seed
// bills the app cannot create):
//   SUPABASE_TEST_URL=... SUPABASE_TEST_ANON_KEY=... \
//   flutter test --no-pub test/integration/sales_tax_report_test.dart
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

  group('sales tax report', skip: skip, () {
    late SupabaseClient owner;
    late SupabasePosRepository repo;
    late String shopId;
    late String ownerStaffId;
    final billA = const Uuid().v4();
    final billB = const Uuid().v4();
    final billC = const Uuid().v4();

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
        email: 'st-${DateTime.now().microsecondsSinceEpoch}@example.test',
        password: 'integration-pass-1',
      );
      shopId = await owner.rpc<String>(
        'create_organization_with_shop',
        params: <String, dynamic>{
          'p_org_name': 'ร้านรายงานภาษี',
          'p_shop_name': 'สาขารายงานภาษี',
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
      repo = await SupabasePosRepository.open(
        deviceClient: device,
        ownerClient: owner,
        shopId: shopId,
      );
      expect(
        await repo.signInWithPin(ownerStaffId, '9999'),
        PinSignInResult.success,
      );

      // Arrange: A normal (107.00), B voided (214.00), C full invoice that
      // replaces B (53.50, buyer data), all dated today.
      String bill(
        String id,
        String no,
        int total,
        int vat,
        int minsAgo, {
        bool voided = false,
        String? full,
      }) =>
          """
        insert into bills (id, shop_id, device_id, no, business_date, at,
            subtotal, service, vat, total, heads_a, heads_c, heads_f,
            method_type, received, voided, void_reason, void_by, void_at, vat_mode, vat_rate,
            is_tax_invoice, rd_machine_code, is_full_invoice,
            replaces_bill_id, buyer_name, buyer_tax_id, buyer_branch)
          select '$id'::uuid, d.shop_id, d.id, '$no',
                 (now() at time zone 'Asia/Bangkok')::date,
                 now() - interval '$minsAgo min', $total, 0, $vat, $total,
                 1, 0, 0, 'cash', $total, $voided,
                 ${voided ? "'ทดสอบ', 'เจ้าของ', now()" : 'null, null, null'}, 'included', 7, true, 'RD-9',
                 ${full != null},
                 ${full != null ? "'$full'::uuid" : 'null'},
                 ${full != null ? "'บริษัท ก'" : 'null'},
                 ${full != null ? "'0105512345678'" : 'null'},
                 ${full != null ? "'00000'" : 'null'}
          from devices d where d.shop_id = '$shopId';
        """;
      sql('''
        update organizations set vat_registered = true
          where id = (select org_id from shops where id = '$shopId');
        set session_replication_role = replica;
        ${bill(billA, 'T-A', 10700, 700, 3)}
        ${bill(billB, 'T-B', 21400, 1400, 2, voided: true)}
        ${bill(billC, 'T-C', 5350, 350, 1, full: billB)}
      ''');
    });

    test('report rows and daily summary carry exact satang', () async {
      // Arrange
      final bkk = DateTime.now().toUtc().add(const Duration(hours: 7));
      final day =
          '${bkk.year}-${bkk.month.toString().padLeft(2, '0')}-'
          '${bkk.day.toString().padLeft(2, '0')}';

      // Act
      final rows = await repo.getSalesTaxReport(day.substring(0, 7));
      final daily = await repo.getDailyDeviceSummary(day, day);

      // Assert
      expect(rows.map((r) => r.no), <String>['T-A', 'T-B', 'T-C']);
      expect(rows[0].docType, 'abb');
      expect(rows[0].base, 10000);
      expect(rows[0].vat, 700);
      expect(rows[0].total, 10700);
      expect(rows[0].rdMachineCode, 'RD-9');
      expect(rows[1].voided, isTrue);
      expect(rows[1].voidReason, 'ทดสอบ');
      expect(rows[2].docType, 'full');
      expect(rows[2].replacesNo, 'T-B');
      expect(rows[2].buyerName, 'บริษัท ก');
      expect(rows[2].buyerTaxId, '0105512345678');
      expect(rows[2].buyerBranch, '00000');
      expect(rows[2].base, 5000);
      expect(daily.map((d) => d.deviceCode).toSet(), hasLength(2));
      final dev = daily.firstWhere((d) => d.deviceCode != 'FULL');
      expect(dev.firstNo, 'T-A');
      expect(dev.lastNo, 'T-B');
      expect(dev.bills, 1);
      expect(dev.voided, 1);
      expect((dev.base, dev.vat, dev.total), (10000, 700, 10700));
      final full = daily.firstWhere((d) => d.deviceCode == 'FULL');
      expect(full.firstNo, 'T-C');
      expect((full.bills, full.voided), (1, 0));
      expect((full.base, full.vat, full.total), (5000, 350, 5350));
    });
  });
}
