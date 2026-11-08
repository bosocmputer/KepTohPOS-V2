import 'package:app/core/data/local/outbox_queue.dart';
import 'package:app/core/data/supabase/supabase_pos_base.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Runs sale commands online when possible and queues them otherwise.
///
/// Offline, or while earlier commands still wait, a command goes to the
/// `outbox` and `local` applies the same domain rules the mock uses, so the
/// screens keep working; sending later reuses each command's own id.
mixin SupabasePosOffline on SupabasePosBase {
  /// Sends [fn] now, or queues it under [id] and applies [local] to a copy of
  /// the state when the server cannot be reached.
  Future<PosState> runCommand(
    String fn,
    String id,
    Map<String, dynamic> params,
    void Function(PosState s) local,
  ) async {
    final queue = outbox;
    if (queue != null && await queue.pendingCount() > 0) {
      return await _queue(queue, fn, id, params, local);
    }
    try {
      await staffRpc<Object?>(fn, params);
    } on PosOfflineException {
      if (queue == null) rethrow;
      return await _queue(queue, fn, id, params, local);
    }
    return await reload();
  }

  Future<PosState> _queue(
    OutboxQueue queue,
    String fn,
    String id,
    Map<String, dynamic> params,
    void Function(PosState s) local,
  ) async {
    final token = offlineToken ?? staffToken;
    if (token == null) {
      throw const PosCommandException('กรุณาเข้าสู่ระบบด้วย PIN ก่อน');
    }
    // Apply first: if the local rules refuse, nothing is queued.
    final next = posState.copy();
    local(next);
    await queue.add(
      id: id,
      fn: fn,
      params: <String, dynamic>{'p_token': token, ...params},
    );
    posState = next.freeze();
    if (!controller.isClosed) controller.add(posState);
    return posState;
  }

  /// Sends queued commands in order, then reloads once nothing is left.
  Future<OutboxFlushResult?> flushOutbox() async {
    final queue = outbox;
    if (queue == null) return null;
    final result = await queue.flush((fn, params) async {
      try {
        await deviceClient.rpc<Object?>(fn, params: params);
      } on http.ClientException {
        throw const OutboxOfflineException();
      } on PostgrestException {
        rethrow;
      }
    });
    if (!result.offline && await queue.pendingCount() == 0) {
      try {
        await reload();
      } on PosCommandException {
        // The next command or flush reloads again.
      }
    }
    return result;
  }
}
