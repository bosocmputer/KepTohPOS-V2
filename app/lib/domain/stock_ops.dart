import 'dart:math' as math;

import 'package:app/domain/ledger.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/roles.dart';

int _stockIdCounter = 0;

String _genStockUid(String prefix, DateTime now) {
  _stockIdCounter = (_stockIdCounter + 1) & 0xFFFFF;
  final ts = now.millisecondsSinceEpoch.toRadixString(36);
  final tail = ts.length > 4 ? ts.substring(ts.length - 4) : ts;
  return '$prefix$tail${_stockIdCounter.toRadixString(36).padLeft(4, '0')}';
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

/// Returns `true` when [ing] must be counted on [date] (`isDue` in
/// `prototype/index.html:1349`).
bool isIngredientDue(PosState s, IngredientItem ing, String date) =>
    ing.countFreq != 'weekly' ||
    (parseKey(date).weekday % 7) == s.shop.weeklyCountDow;

/// Groups [ings] by storage location order (`fridge`, `freezer`, `dry`).
List<MapEntry<String, List<IngredientItem>>> groupIngredientsByLocation(
  List<IngredientItem> ings,
) {
  final result = <MapEntry<String, List<IngredientItem>>>[];
  for (final loc in kLocations.keys) {
    final items = ings.where((i) {
      final norm = kLocations.containsKey(i.location) ? i.location : 'dry';
      return norm == loc;
    }).toList();
    if (items.isNotEmpty) {
      result.add(MapEntry<String, List<IngredientItem>>(loc, items));
    }
  }
  return result;
}

/// Returns the most recent closing count for [ingId] strictly before [date].
double? previousCountOf(PosState s, String ingId, String date) {
  final prevKeys = s.counts.keys.where((k) => k.compareTo(date) < 0).toList()
    ..sort((a, b) => b.compareTo(a));
  for (final k in prevKeys) {
    final v = s.counts[k]?[ingId];
    if (v != null) return v;
  }
  return null;
}

/// Live preview of usage and cost for a single ingredient row during counting.
class StockCountRowCalc {
  const new({this.used, this.cost, this.over = false});

  const new empty() : used = null, cost = null, over = false;

  final double? used;
  final double? cost;
  final bool over;
}

/// Computes live usage & cost preview for [ing] given [dayRow] and
/// [draftValue].
StockCountRowCalc calcDraftCountRow({
  required IngredientItem ing,
  required IngredientDayRow? dayRow,
  required String? draftValue,
}) {
  if (dayRow == null || draftValue == null || draftValue.trim().isEmpty) {
    return const StockCountRowCalc.empty();
  }
  final parsed = double.tryParse(draftValue.trim());
  if (parsed == null) return const StockCountRowCalc.empty();
  final weekly = ing.countFreq == 'weekly';
  final raw = dayRow.avail - parsed;
  final used = weekly ? raw : math.max<double>(0, raw);
  return StockCountRowCalc(
    used: used,
    cost: used * dayRow.unit,
    over: !weekly && raw < 0,
  );
}

/// Saves closing stock counts for [date], rounding each entered value via
/// [roundQty] according to the ingredient's unit (`save` in `index.html:1388`).
void saveDailyCount(
  PosState st, {
  required String date,
  required Map<String, String> draftValues,
}) {
  final saved = <String, double>{};
  for (final ing in st.ingredients) {
    final raw = draftValues[ing.id]?.trim() ?? '';
    if (raw.isEmpty) continue;
    final parsed = double.tryParse(raw);
    if (parsed == null) continue;
    saved[ing.id] = roundQty(parsed, ing.unit);
  }
  st.counts[date] = saved;
}

/// Reopens a closed day by deleting `st.counts[date]`. Restricted to
/// `manager` / `owner` (`me.role != 'cashier'`).
bool reopenClosedDay(
  PosState st, {
  required String date,
  required StaffMember me,
}) {
  if (me.role == 'cashier') return false;
  if (!st.counts.containsKey(date)) return false;
  st.counts.remove(date);
  return true;
}

/// Returns the most recent [PurchaseRecord] for [supplierId].
PurchaseRecord? lastPurchaseForSupplier(
  PosState s,
  String supplierId, {
  String? excludeId,
}) {
  final matches =
      s.purchases
          .where((x) => x.supplierId == supplierId && x.id != excludeId)
          .toList()
        ..sort((a, b) => b.at.compareTo(a.at));
  return matches.firstOrNull;
}

/// Saves a new or edited [PurchaseRecord] into `st.purchases` without mutating
/// `ing.lastCost` (all unit costs derive from `computeLedger`). Editing an
/// existing purchase requires `me.role != 'cashier'`.
bool savePurchase(
  PosState st, {
  required String date,
  required String supplierId,
  required List<PurchaseLine> lines,
  required StaffMember me,
  String note = '',
  String? editId,
  DateTime? now,
}) {
  final validLines = lines
      .where((l) => l.ingId.isNotEmpty && l.qty > 0)
      .map(
        (l) => PurchaseLine(
          ingId: l.ingId,
          qty: l.qty,
          total: l.total >= 0 ? l.total : 0,
        ),
      )
      .toList();
  if (validLines.isEmpty) return false;

  final current = now ?? DateTime.now();
  if (editId != null) {
    if (me.role == 'cashier') return false;
    final idx = st.purchases.indexWhere((x) => x.id == editId);
    if (idx < 0) return false;
    final existing = st.purchases[idx];
    st.purchases[idx] = PurchaseRecord(
      id: existing.id,
      date: date,
      at: existing.at,
      supplierId: supplierId,
      note: note.trim(),
      lines: validLines,
    );
    return true;
  }

  st.purchases.add(
    PurchaseRecord(
      id: _genStockUid('p', current),
      date: date,
      at: current.toUtc().toIso8601String(),
      supplierId: supplierId,
      note: note.trim(),
      lines: validLines,
    ),
  );
  return true;
}

/// Deletes a purchase bill by [purchaseId]. Restricted to `manager`/`owner`.
bool deletePurchase(
  PosState st, {
  required String purchaseId,
  required StaffMember me,
}) {
  if (me.role == 'cashier') return false;
  final before = st.purchases.length;
  st.purchases.removeWhere((x) => x.id == purchaseId);
  return st.purchases.length < before;
}

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
        id: _genStockUid('e', current),
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
