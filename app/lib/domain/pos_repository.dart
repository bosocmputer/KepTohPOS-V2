import 'dart:async';

import 'package:app/domain/models.dart';
import 'package:app/domain/pos_setup_commands.dart';
import 'package:app/domain/stock_balance_ops.dart';

int _shiftCounter = 0;

String _nextShiftUid(DateTime now) {
  _shiftCounter = (_shiftCounter + 1) & 0xFFFFF;
  final ts = now.millisecondsSinceEpoch.toRadixString(36);
  final tail = ts.length > 4 ? ts.substring(ts.length - 4) : ts;
  return 'sh$tail${_shiftCounter.toRadixString(36).padLeft(4, '0')}';
}

/// Finds the currently open shift (`openShiftOf` in `prototype/index.html`).
ShiftRecord? openShiftOf(PosState s) {
  for (final sh in s.shifts) {
    if (sh.closedAt == null) return sh;
  }
  return null;
}

/// Aggregated shift sales and cash drawer stats (`stats(sh)` in `ShiftView`).
class ShiftStats {
  const new({
    required this.bills,
    required this.cash,
    required this.qr,
    required this.transfer,
    required this.expected,
  });

  final int bills;
  final int cash;
  final int qr;
  final int transfer;
  final int expected;
}

/// Computes [ShiftStats] for [sh] (`stats` in `ShiftView` of `index.html`).
ShiftStats calcShiftStats(PosState s, ShiftRecord sh) {
  var bills = 0;
  var cash = 0;
  var qr = 0;
  var transfer = 0;
  for (final b in s.sales) {
    if (b.shiftId != sh.id || b.voided) continue;
    bills++;
    switch (b.methodType) {
      case 'cash':
        cash += b.total;
      case 'qr':
        qr += b.total;
      case 'transfer' || 'card':
        transfer += b.total;
    }
  }
  return ShiftStats(
    bills: bills,
    cash: cash,
    qr: qr,
    transfer: transfer,
    expected: sh.floatAmount + cash,
  );
}

/// Opens a new shift (`OpenShiftForm` in `prototype/index.html`).
ShiftRecord openShift(
  PosState s, {
  required String staffId,
  required int floatAmount,
  DateTime? now,
  String? id,
}) {
  final current = now ?? DateTime.now();
  final sh = ShiftRecord(
    id: id ?? _nextShiftUid(current),
    staffId: staffId,
    openedAt: current.toUtc().toIso8601String(),
    floatAmount: floatAmount,
  );
  s.shifts.add(sh);
  return sh;
}

/// Closes the currently open shift (`ShiftView` in `prototype/index.html`).
ShiftRecord? closeShift(
  PosState s, {
  required String staffId,
  required int counted,
  DateTime? now,
}) {
  final sh = openShiftOf(s);
  if (sh == null) return null;
  final current = now ?? DateTime.now();
  sh
    ..closedAt = current.toUtc().toIso8601String()
    ..counted = counted
    ..closedBy = staffId;
  return sh;
}

/// Outcome of checking a staff PIN.
enum PinSignInResult {
  /// The PIN was correct and the staff member is now signed in.
  success,

  /// The PIN was wrong.
  invalid,

  /// Too many wrong attempts; the staff member is temporarily locked.
  locked,
}

/// Abstract repository contract for reading [PosState] and running commands.
///
/// Commands return a [Future] because real implementations write to a local
/// database or the network; each one broadcasts on [stream] when it finishes.
abstract class PosRepository implements PosSetupCommands {
  /// Current snapshot of [PosState].
  PosState get state;

  /// Stream of [PosState] updates emitted after every command.
  Stream<PosState> get stream;

  /// Currently logged-in staff member (`null` when signed out).
  StaffMember? get currentStaff;

  /// Whether this is local demo data, where export, import and the simulation
  /// tools are safe. They would overwrite or shift real records otherwise.
  bool get isDemoData;

  /// Whether cost and expense data is loaded. It is withheld from cashiers on
  /// the server, so figures derived from it would be wrong when this is false.
  bool get canReadCosts;

  /// Saves kitchen notes on an open table.
  Future<PosState> setTableNotes(String tableId, String notes);

  /// Sends an order round and deducts addon stock.
  Future<PosState> sendOrderRound({
    required DiningTable table,
    required TableTotals cart,
    required StaffMember staff,
    required String timing,
    required String packageId,
    required String notes,
    DateTime? now,
  });

  /// Reduces an already-sent item and restores addon stock.
  Future<PosState> adjustSentItem({
    required String tableId,
    required String kind,
    required String key,
    required int qty,
    required String reason,
    required StaffMember staff,
    DateTime? now,
  });

  /// Settles an order into a bill. [received] is in satang.
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
  });

  /// Voids a bill; returns `false` if not permitted, unknown or already voided.
  Future<bool> voidSale({
    required String billId,
    required StaffMember staff,
    required String reason,
    bool allowCashier = false,
    DateTime? now,
  });

  /// Cancels an unpaid open table and restores its addon stock.
  Future<PosState> cancelTable(String tableId);

  /// Clears a table whose balance is settled.
  Future<PosState> closeTable(String tableId);

  /// Opens a cash shift unless one is already open. Amounts are in satang.
  Future<PosState> openCashShift({
    required String staffId,
    required int floatAmount,
    DateTime? now,
  });

  /// Closes the open cash shift with the counted cash in satang.
  Future<PosState> closeCashShift({
    required String staffId,
    required int counted,
    DateTime? now,
  });

  /// Saves a new or edited purchase bill; returns `false` if not permitted.
  Future<bool> recordPurchase({
    required String date,
    required String supplierId,
    required List<PurchaseLine> lines,
    required StaffMember staff,
    required String note,
    required DateTime now,
    String? editId,
  });

  /// Deletes a purchase bill; returns `false` if not permitted.
  Future<bool> removePurchase({
    required String purchaseId,
    required StaffMember staff,
  });

  /// Saves new or edited daily expenses; returns `false` if not permitted.
  Future<bool> recordExpenses({
    required String date,
    required List<ExpenseDraftLine> lines,
    required StaffMember staff,
    required DateTime now,
    String? editId,
  });

  /// Deletes a daily expense; returns `false` if not permitted.
  Future<bool> removeExpense({
    required String expenseId,
    required StaffMember staff,
  });

  /// Saves the daily stock count and closes the business day.
  Future<void> saveStockCount({
    required String date,
    required Map<String, String> draftValues,
  });

  /// Reopens a closed day; returns `false` if not permitted.
  Future<bool> reopenDay({required String date, required StaffMember staff});

  /// Saves the theme mode and/or palette to the shop settings.
  Future<void> saveThemePreference({String? mode, String? palette});

  /// Checks [pin] for [staffId] and signs that staff member in when correct.
  Future<PinSignInResult> signInWithPin(String staffId, String pin);

  /// Signs out the current staff member.
  Future<void> signOutStaff();

  /// Creates the id for a new bill.
  String newBillId(DateTime now);

  /// Exports the entire current [PosState] snapshot as formatted JSON.
  String exportStateJson();

  /// Replaces the repository's [PosState] from a JSON string snapshot and
  /// broadcasts the imported state to all listeners.
  PosState importStateJson(String rawJson);
}
