import 'dart:math' as math;

import 'package:app/domain/ledger.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/roles.dart';

int _expenseIdCounter = 0;

String _genExpenseUid(DateTime now) {
  _expenseIdCounter = (_expenseIdCounter + 1) & 0xFFFFF;
  final ts = now.millisecondsSinceEpoch.toRadixString(36);
  final tail = ts.length > 4 ? ts.substring(ts.length - 4) : ts;
  return 'e$tail${_expenseIdCounter.toRadixString(36).padLeft(4, '0')}';
}

/// Stock balance status badge (`พอ` / `ใกล้หมด` / `หมด`).
enum StockStatus {
  ok('พอ'),
  low('ใกล้หมด'),
  out('หมด');

  new(this.label);

  final String label;
}

/// Evaluates [StockStatus] against [qty] and target [par] level:
/// - `out`: `qty <= 0`
/// - `low`: `par > 0 && 0 < qty < par`
/// - `ok`: `qty >= par` (or `qty > 0` when `par <= 0`)
StockStatus computeStockStatus(double qty, double par) {
  if (qty <= 0) return StockStatus.out;
  if (par > 0 && qty < par) return StockStatus.low;
  return StockStatus.ok;
}

/// Returns `true` when [unit] is a discrete counting unit (`kCountUnits`).
bool isDiscreteUnit(String unit) => kCountUnits.contains(unit);

/// Draft line for adding or editing daily expenses (`ExpenseModal`).
class ExpenseDraftLine {
  const new({required this.typeId, required this.amount, this.note = ''});

  final String typeId;
  final double amount;
  final String note;
}

/// Finds the latest date strictly before [date] that has recorded expenses.
String? previousExpenseDate(PosState s, String date) {
  final dates =
      s.expenses
          .where((e) => e.date.compareTo(date) < 0)
          .map((e) => e.date)
          .toSet()
          .toList()
        ..sort();
  return dates.lastOrNull;
}

/// Saves new daily expenses or edits an existing expense (`editId`).
/// Editing an existing expense requires `me.role != 'cashier'`.
bool saveExpenses(
  PosState st, {
  required String date,
  required List<ExpenseDraftLine> lines,
  required StaffMember me,
  String? editId,
  DateTime? now,
}) {
  final valid = lines
      .where((l) => l.typeId.isNotEmpty && l.amount > 0)
      .toList();
  if (valid.isEmpty) return false;

  final current = now ?? DateTime.now();
  if (editId != null) {
    if (me.role == 'cashier') return false;
    final idx = st.expenses.indexWhere((e) => e.id == editId);
    if (idx < 0) return false;
    final existing = st.expenses[idx];
    final first = valid.first;
    st.expenses[idx] = ExpenseRecord(
      id: existing.id,
      date: existing.date,
      at: existing.at,
      typeId: first.typeId,
      amount: first.amount,
      note: first.note.trim(),
    );
    return true;
  }

  for (final l in valid) {
    st.expenses.add(
      ExpenseRecord(
        id: _genExpenseUid(current),
        date: date,
        at: current.toUtc().toIso8601String(),
        typeId: l.typeId,
        amount: l.amount,
        note: l.note.trim(),
      ),
    );
  }
  return true;
}

/// Deletes a daily expense by [expenseId]. Restricted to `manager`/`owner`.
bool deleteExpense(
  PosState st, {
  required String expenseId,
  required StaffMember me,
}) {
  if (me.role == 'cashier') return false;
  final before = st.expenses.length;
  st.expenses.removeWhere((e) => e.id == expenseId);
  return st.expenses.length < before;
}

/// Computed balance row for an ingredient (`StockBalance`).
class StockBalanceRow {
  const new({
    required this.ing,
    required this.supplierName,
    required this.qty,
    required this.avgCost,
    required this.lastCost,
    required this.unitCost,
    required this.val,
    required this.need,
    required this.status,
  });

  final IngredientItem ing;
  final String supplierName;
  final double qty;
  final double avgCost;
  final double lastCost;
  final double unitCost;
  final double val;
  final double need;
  final StockStatus status;
}

/// Computes [StockBalanceRow]s for all ingredients in [s] using [ledger] and
/// `s.shop.costMethod` (`'avg'` vs `'last'`).
List<StockBalanceRow> computeStockBalanceRows(PosState s, LedgerResult ledger) {
  final useLast = s.shop.costMethod == 'last';
  return s.ingredients.map((ing) {
    final c = ledger.current[ing.id];
    final qty = c != null ? c.qty : 0.0;
    final avg = c != null ? c.avg : ing.lastCost;
    final last = c != null ? c.last : ing.lastCost;
    final unitCost = useLast ? last : avg;
    final val = qty * unitCost;
    final rawNeed = math.max<double>(0, ing.par - qty);
    final need = rawNeed > 0 ? roundQty(rawNeed, ing.unit) : 0.0;
    final status = computeStockStatus(qty, ing.par);
    final supplierName =
        s.suppliers
            .where((sup) => sup.id == ing.supplierId)
            .map((sup) => sup.name)
            .firstOrNull ??
        '-';
    return StockBalanceRow(
      ing: ing,
      supplierName: supplierName,
      qty: qty,
      avgCost: avg,
      lastCost: last,
      unitCost: unitCost,
      val: val,
      need: need,
      status: status,
    );
  }).toList();
}
