// Runs against a local Supabase stack (and its Docker db container, to seed
// bills the app cannot create):
//   SUPABASE_TEST_URL=... SUPABASE_TEST_ANON_KEY=... \
//   flutter test --no-pub test/integration/full_invoice_test.dart
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

  group('full tax invoice', skip: skip, () {
    late SupabaseClient owner;
    late SupabasePosRepository repo;
    late String shopId;
    late String ownerStaffId;
    final billId = const Uuid().v4();

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
        email: 'fi-${DateTime.now().microsecondsSinceEpoch}@example.test',
        password: 'integration-pass-1',
      );
      shopId = await owner.rpc<String>(
        'create_organization_with_shop',
        params: <String, dynamic>{
          'p_org_name': 'ร้านใบกำกับ',
          'p_shop_name': 'สาขาใบกำกับ',
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
      await repo.openCashShift(staffId: ownerStaffId, floatAmount: 0);

      // Arrange: a VAT shop with one settled bill dated today (tax month).
      sql('''
        update organizations set vat_registered = true
          where id = (select org_id from shops where id = '$shopId');
        update shops set vat_mode = 'included', vat_rate = 7
          where id = '$shopId';
        set session_replication_role = replica;
        insert into bills (id, shop_id, device_id, no, business_date, at,
            subtotal, service, vat, total, heads_a, heads_c, heads_f,
            method_type, received, voided, vat_mode, vat_rate, is_tax_invoice)
          select '$billId'::uuid, d.shop_id, d.id, 'FI-SEED-1',
                 (now() at time zone 'Asia/Bangkok')::date, now(),
                 10700, 0, 700, 10700, 1, 0, 0, 'cash', 10700, false,
                 'included', 7, true
          from devices d where d.shop_id = '$shopId';
        insert into bill_lines (shop_id, bill_id, line_no, type, name, qty, price)
        values ('$shopId', '$billId', 1, 'buffet', 'บุฟเฟต์', 1, 10700);
      ''');
    });

    test('issues a -F- bill with buyer data and voids the old one', () async {
      // Arrange
      await repo.reload();

      // Act
      final created = await repo.issueFullInvoice(
        billId: billId,
        buyerName: 'บริษัท ลูกค้า จำกัด',
        buyerAddress: '99 ถ.สุขุมวิท กรุงเทพฯ',
        buyerTaxId: '0105512345678',
        buyerBranch: '00000',
      );

      // Assert
      expect(created.no, matches(RegExp(r'^\d{5}-F-\d{6}$')));
      expect(created.isFullInvoice, isTrue);
      expect(created.replacesBillId, billId);
      expect(created.buyerName, 'บริษัท ลูกค้า จำกัด');
      expect(created.buyerTaxId, '0105512345678');
      expect(created.buyerBranch, '00000');
      expect(created.total, 10700);
      expect(created.voided, isFalse);
      expect(repo.state.sales.firstWhere((b) => b.id == billId).voided, isTrue);
    });
  });
}
