import 'package:app/core/data/supabase/supabase_pos_base.dart';
import 'package:app/core/data/supabase/supabase_pos_offline.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';

/// Tables, bills and shifts through server RPCs. Each resent id is safe to
/// retry, and the server identifies the staff member from the session token.
/// Offline, the same commands queue and apply locally (see
/// [SupabasePosOffline]).
mixin SupabasePosSaleCommands on SupabasePosBase, SupabasePosOffline
    implements PosRepository {
  Map<String, int> _positive(Map<String, int> addons) => <String, int>{
    for (final e in addons.entries)
      if (e.value > 0) e.key: e.value,
  };

  String _at(DateTime? now) =>
      (now ?? DateTime.now()).toUtc().toIso8601String();

  /// The open session of [tableId], or a new id that the first command opens.
  String _session(String tableId) => sessionByTable[tableId] ??= newId();

  @override
  Future<PosState> setTableNotes(String tableId, String notes) async {
    final session = sessionByTable[tableId];
    if (session == null) return posState;
    return await runCommand('set_table_notes', newId(), <String, dynamic>{
      'p_session_id': session,
      'p_notes': notes,
    }, (s) => s.openTables[tableId]?.notes = notes);
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
    final id = newId();
    return await runCommand(
      'send_round',
      id,
      <String, dynamic>{
        'p_round_id': id,
        'p_session_id': _session(table.id),
        'p_table_id': table.id,
        'p_package_id': packageId,
        'p_timing': timing,
        'p_heads_a': cart.a,
        'p_heads_c': cart.c,
        'p_heads_f': cart.f,
        'p_addons': _positive(cart.ad),
        'p_at': _at(now),
        'p_notes': notes,
      },
      (s) =>
          sendRound(s, table, cart, staff, timing, packageId, notes, now: now),
    );
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
    final id = newId();
    return await runCommand('adjust_sent', id, <String, dynamic>{
      'p_adjustment_id': id,
      'p_session_id': session,
      'p_kind': kind,
      'p_key': key,
      'p_qty': qty,
      'p_reason': reason,
      'p_at': _at(now),
    }, (s) => adjustSent(s, tableId, kind, key, qty, reason, staff, now: now));
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
    String? rounding,
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
    // This device numbers its own receipts, online or not, so the number a
    // customer sees offline is the one the server keeps.
    final prefix = receiptPrefix;
    final seq = prefix == null ? null : receiptSeq + 1;
    final result = await runCommand(
      'settle_bill',
      billId,
      <String, dynamic>{
        'p_bill_id': billId,
        'p_session_id': _session(table.id),
        'p_table_id': table.id,
        'p_package_id': effectivePackage,
        'p_timing': effectiveTiming,
        'p_heads_a': cart.a,
        'p_heads_c': cart.c,
        'p_heads_f': cart.f,
        'p_addons': _positive(cart.ad),
        'p_method_id': method.id,
        'p_received': received,
        'p_expected_total': orderOf(
          posState,
          pkg,
          totals,
          roundingOverride: rounding,
        ).total,
        'p_at': _at(now),
        'p_bank_account_id': bankAccount?.id,
        'p_notes': notes,
        'p_seq': seq,
        'p_rounding': ?rounding,
      },
      (s) {
        if (prefix == null) throw const PosOfflineException();
        settle(
          s,
          table,
          cart,
          staff,
          timing: timing,
          pkgId: packageId,
          method: method,
          received: received,
          billId: billId,
          bankAccount: bankAccount,
          notes: notes,
          rounding: rounding,
          now: now,
        );
        final i = s.sales.indexWhere((b) => b.id == billId);
        s.sales[i] = BillRecord.fromJson(<String, dynamic>{
          ...s.sales[i].toJson(),
          'no': '$prefix-${seq.toString().padLeft(6, '0')}',
          'rdMachineCode': rdMachineCode,
          'isTaxInvoice':
              s.shop.vatRegistered &&
              s.shop.vatMode != 'none' &&
              rdMachineCode != null,
        });
      },
    );
    if (seq != null) receiptSeq = seq;
    return result;
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
    var ok = true;
    await runCommand(
      'void_bill',
      newId(),
      <String, dynamic>{
        'p_bill_id': billId,
        'p_reason': reason,
        'p_at': _at(now),
      },
      (s) => ok = voidBill(
        s,
        billId: billId,
        me: staff,
        reason: reason,
        allowCashier: allowCashier,
        now: now,
      ),
    );
    return ok;
  }

  @override
  Future<BillRecord> reissueBill({
    required String billId,
    required String reason,
    String? methodId,
    String? bankAccountId,
  }) async {
    final newBillId = newId();
    await staffRpc<Object?>('reissue_bill', <String, dynamic>{
      'p_shop_id': shopId,
      'p_bill_id': billId,
      'p_new_id': newBillId,
      'p_reason': reason,
      'p_method_id': ?methodId,
      'p_bank_account_id': ?bankAccountId,
    });
    final state = await reload();
    return state.sales.firstWhere((b) => b.id == newBillId);
  }

  @override
  Future<PosState> cancelTable(String tableId) async {
    final session = sessionByTable[tableId];
    if (session == null) return posState;
    return await runCommand(
      'cancel_table',
      newId(),
      <String, dynamic>{'p_session_id': session, 'p_at': _at(null)},
      (s) {
        cancelOpenTable(s, tableId);
        sessionByTable.remove(tableId);
      },
    );
  }

  @override
  Future<PosState> closeTable(String tableId) async {
    final session = sessionByTable[tableId];
    if (session == null) return posState;
    return await runCommand(
      'close_table',
      newId(),
      <String, dynamic>{'p_session_id': session, 'p_at': _at(null)},
      (s) {
        s.openTables.remove(tableId);
        sessionByTable.remove(tableId);
      },
    );
  }

  @override
  Future<PosState> openCashShift({
    required String staffId,
    required int floatAmount,
    DateTime? now,
  }) async {
    if (openShiftOf(posState) != null) return posState;
    final id = newId();
    return await runCommand(
      'open_shift',
      id,
      <String, dynamic>{
        'p_shift_id': id,
        'p_float': floatAmount,
        'p_at': _at(now),
      },
      (s) => openShift(
        s,
        staffId: staffId,
        floatAmount: floatAmount,
        now: now,
        id: id,
      ),
    );
  }

  @override
  Future<PosState> closeCashShift({
    required String staffId,
    required int counted,
    DateTime? now,
  }) async {
    final shift = openShiftOf(posState);
    if (shift == null) return posState;
    return await runCommand('close_shift', newId(), <String, dynamic>{
      'p_shift_id': shift.id,
      'p_counted': counted,
      'p_at': _at(now),
    }, (s) => closeShift(s, staffId: staffId, counted: counted, now: now));
  }
}
