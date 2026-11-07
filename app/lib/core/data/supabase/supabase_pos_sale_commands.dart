import 'package:app/core/data/supabase/supabase_pos_base.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';

/// Tables, bills and shifts through server RPCs. Each resent id is safe to
/// retry, and the server identifies the staff member from the session token.
mixin SupabasePosSaleCommands on SupabasePosBase implements PosRepository {
  Map<String, int> _positive(Map<String, int> addons) => <String, int>{
    for (final e in addons.entries)
      if (e.value > 0) e.key: e.value,
  };

  String _at(DateTime? now) =>
      (now ?? DateTime.now()).toUtc().toIso8601String();

  @override
  Future<PosState> setTableNotes(String tableId, String notes) async {
    final session = sessionByTable[tableId];
    if (session == null) return posState;
    await staffRpc<bool>('set_table_notes', <String, dynamic>{
      'p_session_id': session,
      'p_notes': notes,
    });
    return await reload();
  }

  @override
  Future<PosState> sendOrderRound({
    required DiningTable table,
    required TableTotals cart,
    required StaffMember staff,
    required String timing,
    required String packageId,
    required String notes,
    DateTime? now,
  }) async {
    await staffRpc<void>('send_round', <String, dynamic>{
      'p_round_id': newId(),
      'p_session_id': sessionByTable[table.id] ?? newId(),
      'p_table_id': table.id,
      'p_package_id': packageId,
      'p_timing': timing,
      'p_heads_a': cart.a,
      'p_heads_c': cart.c,
      'p_heads_f': cart.f,
      'p_addons': _positive(cart.ad),
      'p_at': _at(now),
      'p_notes': notes,
    });
    return await reload();
  }

  @override
  Future<PosState> adjustSentItem({
    required String tableId,
    required String kind,
    required String key,
    required int qty,
    required String reason,
    required StaffMember staff,
    DateTime? now,
  }) async {
    final session = sessionByTable[tableId];
    if (session == null) return posState;
    await staffRpc<bool>('adjust_sent', <String, dynamic>{
      'p_adjustment_id': newId(),
      'p_session_id': session,
      'p_kind': kind,
      'p_key': key,
      'p_qty': qty,
      'p_reason': reason,
      'p_at': _at(now),
    });
    return await reload();
  }

  @override
  Future<PosState> settleOrder({
    required DiningTable table,
    required TableTotals cart,
    required StaffMember staff,
    required String timing,
    required String packageId,
    required PaymentMethod method,
    required int received,
    required String billId,
    required String notes,
    BankAccountItem? bankAccount,
    DateTime? now,
  }) async {
    final open = posState.openTables[table.id];
    final effectivePackage = open?.packageId ?? packageId;
    final effectiveTiming = open?.timing ?? timing;
    final pkg = posState.packages
        .where((p) => p.id == effectivePackage)
        .firstOrNull;
    if (pkg == null) {
      throw const PosCommandException('ไม่พบแพ็กเกจของโต๊ะนี้');
    }
    final totals = effectiveTiming == 'after' && open != null
        ? mergeTotals(tableTotals(open), cart)
        : cart;
    await staffRpc<Map<String, dynamic>>('settle_bill', <String, dynamic>{
      'p_bill_id': billId,
      'p_session_id': sessionByTable[table.id] ?? newId(),
      'p_table_id': table.id,
      'p_package_id': effectivePackage,
      'p_timing': effectiveTiming,
      'p_heads_a': cart.a,
      'p_heads_c': cart.c,
      'p_heads_f': cart.f,
      'p_addons': _positive(cart.ad),
      'p_method_id': method.id,
      'p_received': received,
      'p_expected_total': orderOf(posState, pkg, totals).total,
      'p_at': _at(now),
      'p_bank_account_id': bankAccount?.id,
      'p_notes': notes,
    });
    return await reload();
  }

  @override
  Future<bool> voidSale({
    required String billId,
    required StaffMember staff,
    required String reason,
    bool allowCashier = false,
    DateTime? now,
  }) async {
    if (!allowCashier && staff.role == 'cashier') return false;
    final ok = await staffRpc<bool>('void_bill', <String, dynamic>{
      'p_bill_id': billId,
      'p_reason': reason,
      'p_at': _at(now),
    });
    if (ok) await reload();
    return ok;
  }

  @override
  Future<PosState> cancelTable(String tableId) async {
    final session = sessionByTable[tableId];
    if (session == null) return posState;
    await staffRpc<void>('cancel_table', <String, dynamic>{
      'p_session_id': session,
      'p_at': _at(null),
    });
    return await reload();
  }

  @override
  Future<PosState> closeTable(String tableId) async {
    final session = sessionByTable[tableId];
    if (session == null) return posState;
    await staffRpc<void>('close_table', <String, dynamic>{
      'p_session_id': session,
      'p_at': _at(null),
    });
    return await reload();
  }

  @override
  Future<PosState> openCashShift({
    required String staffId,
    required int floatAmount,
    DateTime? now,
  }) async {
    if (openShiftOf(posState) != null) return posState;
    await staffRpc<void>('open_shift', <String, dynamic>{
      'p_shift_id': newId(),
      'p_float': floatAmount,
      'p_at': _at(now),
    });
    return await reload();
  }

  @override
  Future<PosState> closeCashShift({
    required String staffId,
    required int counted,
    DateTime? now,
  }) async {
    final shift = openShiftOf(posState);
    if (shift == null) return posState;
    await staffRpc<void>('close_shift', <String, dynamic>{
      'p_shift_id': shift.id,
      'p_counted': counted,
      'p_at': _at(now),
    });
    return await reload();
  }
}
