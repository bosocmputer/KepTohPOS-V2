import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';

/// In-memory implementation of the [PosRepository] write commands.
///
/// Each command runs the existing domain function on a copy of the state, so
/// the rules stay in `app/lib/domain` and are shared with the offline path.
mixin MockPosCommands implements PosRepository {
  /// Applies [mutator] to a copy of the state and broadcasts the result.
  PosState update(void Function(PosState s) mutator);

  int _fullInvoiceSeq = 0;

  @override
  Future<PosState> setTableNotes(String tableId, String notes) async =>
      update((s) => s.openTables[tableId]?.notes = notes);

  @override
  Future<PosState> sendOrderRound({
    required DiningTable table,
    required TableTotals cart,
    required StaffMember staff,
    required String timing,
    required String packageId,
    required String notes,
    DateTime? now,
  }) async => update(
    (s) => sendRound(s, table, cart, staff, timing, packageId, notes, now: now),
  );

  @override
  Future<PosState> adjustSentItem({
    required String tableId,
    required String kind,
    required String key,
    required int qty,
    required String reason,
    required StaffMember staff,
    DateTime? now,
  }) async => update(
    (s) => adjustSent(s, tableId, kind, key, qty, reason, staff, now: now),
  );

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
  }) async => update(
    (s) => settle(
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
      now: now,
    ),
  );

  @override
  Future<bool> voidSale({
    required String billId,
    required StaffMember staff,
    required String reason,
    bool allowCashier = false,
    DateTime? now,
  }) async {
    var ok = false;
    update(
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
    late BillRecord created;
    update((s) {
      final old = s.sales.firstWhere((b) => b.id == billId);
      if (old.voided) throw const PosCommandException('บิลนี้ถูกยกเลิกแล้ว');
      final at = DateTime.now().toUtc().toIso8601String();
      old
        ..voided = true
        ..voidReason = reason.trim().isEmpty ? 'ไม่ระบุ' : reason.trim()
        ..voidBy = 'เจ้าของ'
        ..voidAt = at;
      created = BillRecord.fromJson(<String, dynamic>{
        ...old.toJson(),
        'id': 'r${s.sales.length + 1}-${old.id}',
        'no': '${old.no}-R',
        'voided': false,
        'voidReason': null,
        'voidBy': null,
        'voidAt': null,
        'replacesBillId': old.id,
        'methodId': ?methodId,
        'bankAccountId': ?bankAccountId,
      });
      s.sales.add(created);
    });
    return created;
  }

  @override
  Future<BillRecord> issueFullInvoice({
    required String billId,
    required String buyerName,
    required String buyerAddress,
    String? buyerTaxId,
    String? buyerBranch,
  }) async {
    late BillRecord created;
    update((s) {
      final old = s.sales.firstWhere((b) => b.id == billId);
      if (old.voided) throw const PosCommandException('บิลนี้ถูกยกเลิกแล้ว');
      if (old.isFullInvoice) {
        throw const PosCommandException('บิลนี้เป็นใบกำกับภาษีเต็มรูปแล้ว');
      }
      final seq = ++_fullInvoiceSeq;
      old
        ..voided = true
        ..voidReason = 'ออกใบกำกับภาษีเต็มรูปแทน'
        ..voidBy = 'เจ้าของ'
        ..voidAt = DateTime.now().toUtc().toIso8601String();
      created = BillRecord.fromJson(<String, dynamic>{
        ...old.toJson(),
        'id': 'f$seq-${old.id}',
        'no': '${s.shop.branchCode}-F-${seq.toString().padLeft(6, '0')}',
        'voided': false,
        'voidReason': null,
        'voidBy': null,
        'voidAt': null,
        'isTaxInvoice': true,
        'replacesBillId': old.id,
        'isFullInvoice': true,
        'buyerName': buyerName.trim(),
        'buyerAddress': buyerAddress.trim(),
        'buyerTaxId': ?buyerTaxId,
        'buyerBranch': ?buyerBranch,
      });
      s.sales.add(created);
    });
    return created;
  }

  @override
  Future<PosState> cancelTable(String tableId) async =>
      update((s) => cancelOpenTable(s, tableId));

  @override
  Future<PosState> closeTable(String tableId) async =>
      update((s) => s.openTables.remove(tableId));

  @override
  Future<PosState> openCashShift({
    required String staffId,
    required int floatAmount,
    DateTime? now,
  }) async => update((s) {
    if (openShiftOf(s) == null) {
      openShift(s, staffId: staffId, floatAmount: floatAmount, now: now);
    }
  });

  @override
  Future<PosState> closeCashShift({
    required String staffId,
    required int counted,
    DateTime? now,
  }) async => update(
    (s) => closeShift(s, staffId: staffId, counted: counted, now: now),
  );

  @override
  Future<bool> recordPurchase({
    required String date,
    required String supplierId,
    required List<PurchaseLine> lines,
    required StaffMember staff,
    required String note,
    required DateTime now,
    String? editId,
  }) async {
    var ok = false;
    update((s) {
      ok = savePurchase(
        s,
        date: date,
        supplierId: supplierId,
        lines: lines,
        me: staff,
        note: note,
        editId: editId,
        now: now,
      );
    });
    return ok;
  }

  @override
  Future<bool> removePurchase({
    required String purchaseId,
    required StaffMember staff,
  }) async {
    var ok = false;
    update((s) => ok = deletePurchase(s, purchaseId: purchaseId, me: staff));
    return ok;
  }

  @override
  Future<bool> recordExpenses({
    required String date,
    required List<ExpenseDraftLine> lines,
    required StaffMember staff,
    required DateTime now,
    String? editId,
  }) async {
    var ok = false;
    update((s) {
      ok = saveExpenses(
        s,
        date: date,
        lines: lines,
        me: staff,
        editId: editId,
        now: now,
      );
    });
    return ok;
  }

  @override
  Future<bool> removeExpense({
    required String expenseId,
    required StaffMember staff,
  }) async {
    var ok = false;
    update((s) => ok = deleteExpense(s, expenseId: expenseId, me: staff));
    return ok;
  }

  @override
  Future<void> saveStockCount({
    required String date,
    required Map<String, String> draftValues,
  }) async {
    update((s) => saveDailyCount(s, date: date, draftValues: draftValues));
  }

  @override
  Future<bool> reopenDay({
    required String date,
    required StaffMember staff,
  }) async {
    var ok = false;
    update((s) => ok = reopenClosedDay(s, date: date, me: staff));
    return ok;
  }

  @override
  Future<void> saveThemePreference({String? mode, String? palette}) async {
    update((s) {
      if (mode != null && s.shop.themeMode != mode) {
        s.shop = s.shop.copyWith(themeMode: mode);
      }
      if (palette != null && s.shop.themePalette != palette) {
        s.shop = s.shop.copyWith(themePalette: palette);
      }
    });
  }
}
