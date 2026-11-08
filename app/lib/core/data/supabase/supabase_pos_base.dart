import 'dart:async';

import 'package:app/core/data/local/outbox_queue.dart';
import 'package:app/core/data/supabase/supabase_state_loader.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Shared state and server calls for the Supabase repository.
///
/// [deviceClient] holds the paired device's anonymous session and runs sales.
/// [ownerClient] holds the owner's real login, which setup changes require;
/// the two stay separate so an owner login never replaces the device session.
abstract class SupabasePosBase {
  new({
    required this.deviceClient,
    required this.ownerClient,
    required this.shopId,
    required SupabaseSnapshot snapshot,
  }) : posState = snapshot.state,
       sessionByTable = snapshot.sessionByTable,
       organizationId = snapshot.organizationId,
       costsLoaded = snapshot.canReadCosts;

  final SupabaseClient deviceClient;
  final SupabaseClient? ownerClient;
  final String shopId;
  final StreamController<PosState> controller =
      StreamController<PosState>.broadcast();

  PosState posState;
  Map<String, String> sessionByTable;
  String organizationId;
  bool costsLoaded;
  String? staffToken;
  String? signedInStaffId;

  /// Commands made offline; set once the browser database is open.
  OutboxQueue? outbox;

  /// `BRANCH-POSxx`, so this device can number its own receipts offline;
  /// `null` leaves numbering to the server.
  String? receiptPrefix;

  /// The last receipt number this device used.
  int receiptSeq = 0;

  /// Whether a real owner account is signed in for setup changes.
  bool get hasOwnerSession {
    final user = ownerClient?.auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  /// Returns a time-ordered id for a new record.
  String newId() => _uuid.v7();

  /// Keeps [id] when it is already a server id; the domain creates local-style
  /// ids such as `pk123` for new items, and those become new server ids.
  String serverId(String id) => Uuid.isValidUUID(fromString: id) ? id : newId();

  /// Maps server failures to messages staff can act on.
  PosCommandException describeError(Object error) {
    if (error is PostgrestException) {
      return switch (error.code) {
        '42501' => const PosCommandException('ไม่มีสิทธิ์ทำรายการนี้'),
        'P0001' => const PosCommandException(
          'ยอดไม่ตรงกับเซิร์ฟเวอร์ กรุณาโหลดข้อมูลใหม่แล้วลองอีกครั้ง',
        ),
        '23505' => const PosCommandException(
          'รายการนี้เปิดอยู่แล้วจากอีกเครื่อง กรุณาโหลดข้อมูลใหม่',
        ),
        '22023' => const PosCommandException('ข้อมูลไม่ถูกต้อง'),
        '23503' => const PosCommandException(
          'ลบไม่ได้ เพราะยังมีรายการอื่นใช้ข้อมูลนี้อยู่',
        ),
        _ => const PosCommandException('ทำรายการไม่สำเร็จ'),
      };
    }
    if (error is http.ClientException) return const PosOfflineException();
    return const PosCommandException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
  }

  /// Calls a staff RPC with the session token, translating failures.
  Future<T> staffRpc<T>(String fn, Map<String, dynamic> params) async {
    final token = staffToken;
    if (token == null) {
      throw const PosCommandException('กรุณาเข้าสู่ระบบด้วย PIN ก่อน');
    }
    try {
      return await deviceClient.rpc<T>(
        fn,
        params: <String, dynamic>{'p_token': token, ...params},
      );
    } on Object catch (e) {
      throw describeError(e);
    }
  }

  /// Reloads the snapshot from the server and broadcasts it.
  Future<PosState> reload() async {
    // Server data lacks what is still queued; keep the local state until the
    // outbox has been sent.
    final queue = outbox;
    if (queue != null && await queue.pendingCount() > 0) return posState;
    final me = posState.staff.where((x) => x.id == signedInStaffId).firstOrNull;
    final SupabaseSnapshot snapshot;
    try {
      snapshot = await SupabaseStateLoader(deviceClient, shopId).load(
        currentStaffId: signedInStaffId ?? '',
        token: staffToken,
        readsCosts: me?.seesCosts ?? false,
      );
    } on Object catch (e) {
      throw describeError(e);
    }
    posState = snapshot.state;
    sessionByTable = snapshot.sessionByTable;
    organizationId = snapshot.organizationId;
    costsLoaded = snapshot.canReadCosts;
    if (!controller.isClosed) controller.add(posState);
    return posState;
  }
}
