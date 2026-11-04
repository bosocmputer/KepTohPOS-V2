import 'dart:math' as math;

import 'package:app/domain/ledger.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/roles.dart';

export 'package:app/domain/stock_balance_ops.dart';

int _stockIdCounter = 0;

String _genStockUid(String prefix, DateTime now) {
  _stockIdCounter = (_stockIdCounter + 1) & 0xFFFFF;
  final ts = now.millisecondsSinceEpoch.toRadixString(36);
  final tail = ts.length > 4 ? ts.substring(ts.length - 4) : ts;
  return '$prefix$tail${_stockIdCounter.toRadixString(36).padLeft(4, '0')}';
}

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
