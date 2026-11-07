import 'package:app/domain/domain.dart';

/// In-memory implementation of the [PosRepository] write commands.
///
/// Each command runs the existing domain function on a copy of the state, so
/// the rules stay in `app/lib/domain` and are shared with the offline path.
mixin MockPosCommands implements PosRepository {
  /// Applies [mutator] to a copy of the state and broadcasts the result.
  PosState update(void Function(PosState s) mutator);

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
