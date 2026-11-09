import 'dart:async';

import 'package:app/core/data/local/offline_credentials.dart';
import 'package:app/core/data/local/shop_snapshot_store.dart';
import 'package:app/core/data/supabase/supabase_pos_base.dart';
import 'package:app/core/data/supabase/supabase_pos_offline.dart';
import 'package:app/core/data/supabase/supabase_pos_sale_commands.dart';
import 'package:app/core/data/supabase/supabase_pos_setup_commands.dart';
import 'package:app/core/data/supabase/supabase_pos_stock_commands.dart';
import 'package:app/core/data/supabase/supabase_state_loader.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [PosRepository] backed by Supabase RPCs, for a paired POS device.
///
/// The server recalculates and checks every bill. This class keeps a snapshot
/// in [PosState] so the existing domain code and screens work unchanged.
class SupabasePosRepository extends SupabasePosBase
    with
        SupabasePosOffline,
        SupabasePosSaleCommands,
        SupabasePosStockCommands,
        SupabasePosSetupCommands
    implements PosRepository {
  new({
    required super.deviceClient,
    required super.ownerClient,
    required super.shopId,
    required super.snapshot,
  });

  /// Restarts from a snapshot saved by [toSnapshot], for opening the app
  /// without a connection. Costs are never in it.
  factory restore({
    required SupabaseClient deviceClient,
    required String shopId,
    required Map<String, dynamic> data,
    SupabaseClient? ownerClient,
  }) =>
      SupabasePosRepository(
          deviceClient: deviceClient,
          ownerClient: ownerClient,
          shopId: shopId,
          snapshot: SupabaseSnapshot(
            state: PosState.fromJson(data['state'] as Map<String, dynamic>)
                .copy()
                .freeze(),
            sessionByTable: Map<String, String>.from(
              data['sessionByTable'] as Map<String, dynamic>,
            ),
            organizationId: data['organizationId'] as String,
            canReadCosts: false,
          ),
        )
        ..receiptPrefix = data['receiptPrefix'] as String?
        ..receiptSeq = (data['receiptSeq'] as num? ?? 0).toInt();

  /// Loads the shop for a paired device.
  ///
  /// With [deviceUserId] (the device's auth user) the repository learns this
  /// device's receipt prefix and last number, so it can number receipts
  /// itself, including offline.
  static Future<SupabasePosRepository> open({
    required SupabaseClient deviceClient,
    required String shopId,
    SupabaseClient? ownerClient,
    String? deviceUserId,
  }) async {
    final snapshot = await SupabaseStateLoader(
      deviceClient,
      shopId,
    ).load(currentStaffId: '');
    final repo = SupabasePosRepository(
      deviceClient: deviceClient,
      ownerClient: ownerClient,
      shopId: shopId,
      snapshot: snapshot,
    );
    if (deviceUserId != null) {
      final device = await deviceClient
          .from('devices')
          .select('code, receipt_seq')
          .eq('auth_user_id', deviceUserId)
          .maybeSingle();
      final shop = await deviceClient
          .from('shops')
          .select('branch_code')
          .eq('id', shopId)
          .single();
      if (device != null) {
        repo
          ..receiptPrefix = '${shop['branch_code']}-${device['code']}'
          ..receiptSeq = (device['receipt_seq'] as num).toInt();
      }
    }
    return repo;
  }

  /// What `restore` needs, with costs removed.
  Map<String, dynamic> toSnapshot() => <String, dynamic>{
    'state': stripCosts(posState.toJson()),
    'sessionByTable': sessionByTable,
    'organizationId': organizationId,
    'receiptPrefix': receiptPrefix,
    'receiptSeq': receiptSeq,
  };

  @override
  PosState get state => posState;

  @override
  Stream<PosState> get stream => controller.stream;

  @override
  StaffMember? get currentStaff => posState.staff
      .where((x) => x.id == signedInStaffId && x.active)
      .firstOrNull;

  @override
  bool get isDemoData => false;

  @override
  bool get canEditSetup => hasOwnerSession;

  @override
  bool get canReadCosts => costsLoaded;

  @override
  String newBillId(DateTime now) => newId();

  @override
  Future<PinSignInResult> signInWithPin(String staffId, String pin) async {
    final Map<String, dynamic> result;
    try {
      result = await deviceClient.rpc<Map<String, dynamic>>(
        'verify_staff_pin',
        params: <String, dynamic>{'p_staff_id': staffId, 'p_pin': pin},
      );
    } on Object catch (e) {
      final error = describeError(e);
      if (error is PosOfflineException && credentials != null) {
        return await _signInOffline(staffId, pin);
      }
      throw error;
    }
    if (result['ok'] != true) {
      return result['reason'] == 'locked'
          ? PinSignInResult.locked
          : PinSignInResult.invalid;
    }
    staffToken = result['session_token'] as String?;
    offlineToken = result['offline_token'] as String?;
    signedInStaffId = staffId;
    final token = offlineToken;
    final expires = result['offline_expires_at'] as String?;
    if (token != null && expires != null) {
      await credentials?.save(
        staffId: staffId,
        pin: pin,
        offlineToken: token,
        expiresAt: DateTime.parse(expires),
      );
    }
    await reload();
    return PinSignInResult.success;
  }

  Future<PinSignInResult> _signInOffline(String staffId, String pin) async {
    final check = await credentials!.verify(staffId, pin);
    switch (check.result) {
      case OfflinePinResult.success:
        staffToken = check.token;
        offlineToken = check.token;
        signedInStaffId = staffId;
        if (!controller.isClosed) controller.add(posState);
        return PinSignInResult.success;
      case OfflinePinResult.locked:
        return PinSignInResult.locked;
      case OfflinePinResult.invalid:
        return PinSignInResult.invalid;
      case OfflinePinResult.unknown:
      case OfflinePinResult.expired:
        throw const PosCommandException(
          'ตอนนี้ออฟไลน์ และคนนี้ยังไม่ได้เข้าเครื่องนี้ใน 7 วันที่ผ่านมา '
          'กรุณาให้คนที่เคยเข้าแล้วใช้งานไปก่อน',
        );
    }
  }

  @override
  Future<void> signOutStaff() async {
    final token = staffToken;
    staffToken = null;
    offlineToken = null;
    signedInStaffId = null;
    if (token != null) {
      try {
        await deviceClient.rpc<void>(
          'end_staff_session',
          params: <String, dynamic>{'p_token': token},
        );
      } on Object {
        // The token is already forgotten here and expires on the server.
      }
    }
    try {
      await reload();
    } on PosOfflineException {
      if (!controller.isClosed) controller.add(posState);
    }
  }

  /// Applies theme changes locally, and saves them when an owner is signed in.
  /// A device-only session cannot write shop settings.
  @override
  Future<void> saveThemePreference({String? mode, String? palette}) async {
    final next = posState.copy();
    next.shop = next.shop.copyWith(themeMode: mode, themePalette: palette);
    posState = next.freeze();
    if (!controller.isClosed) controller.add(posState);
    if (!hasOwnerSession) return;
    try {
      await ownerClient!
          .from('shops')
          .update(<String, dynamic>{
            'theme_mode': ?mode,
            'theme_palette': ?palette,
          })
          .eq('id', shopId);
    } on Object {
      // The appearance still applies on this device; the next save retries it.
    }
  }

  @override
  String exportStateJson() =>
      throw const PosCommandException('ไม่รองรับการส่งออกในโหมดร้านจริง');

  @override
  PosState importStateJson(String rawJson) =>
      throw const PosCommandException('ไม่รองรับการนำเข้าในโหมดร้านจริง');
}
