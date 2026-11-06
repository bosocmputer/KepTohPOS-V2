import 'package:app/domain/models.dart';
import 'package:app/domain/roles.dart';
import 'package:app/domain/settle.dart';
import 'package:app/domain/setup_ops.dart';

/// Clears all daily transactions to zero while keeping master catalogs intact.
SetupCrudResult clearDailyTransactionsInState(PosState s, {DateTime? now}) {
  s.startDate = dkey(now ?? DateTime.now());
  s.seq.clear();
  s.openTables.clear();
  s.shifts.clear();
  s.sales.clear();
  s.purchases.clear();
  s.counts.clear();
  s.initialStock.clear();
  s.expenses.clear();
  return const SetupCrudResult.success('เริ่มข้อมูลรายวันใหม่ (0 บิล) แล้ว');
}

/// Advances the simulated calendar by 1 day (shifts recorded history -1 day).
///
/// Guards against advancing while any table or shift is still open so active
/// sessions are properly closed first.
SetupCrudResult advanceSimulationDayInState(PosState s) {
  if (s.openTables.isNotEmpty) {
    return const SetupCrudResult.failure(
      'ยังมีโต๊ะที่เปิดค้างอยู่ กรุณาเช็กบิลและเก็บโต๊ะก่อนข้ามวัน',
      guard: true,
    );
  }
  if (openShiftOf(s) != null) {
    return const SetupCrudResult.failure(
      'ยังมีกะที่เปิดค้างอยู่ กรุณาปิดกะและนับเงินสดก่อนข้ามวัน',
      guard: true,
    );
  }

  String shKey(String k) => dkey(addDays(parseKey(k), -1));
  String shIso(String iso) =>
      DateTime.parse(iso)
          .subtract(const Duration(days: 1))
          .toUtc()
          .toIso8601String();

  s.startDate = shKey(s.startDate);
  final nextSeq = <String, int>{
    for (final e in s.seq.entries) shKey(e.key): e.value,
  };
  s.seq
    ..clear()
    ..addAll(nextSeq);
  final nextCounts = <String, Map<String, double>>{
    for (final e in s.counts.entries) shKey(e.key): e.value,
  };
  s.counts
    ..clear()
    ..addAll(nextCounts);

  for (var i = 0; i < s.sales.length; i++) {
    final b = s.sales[i];
    final nd = shKey(b.date);
    final tail = b.no.contains('-') ? b.no.split('-').last : b.no;
    s.sales[i] = BillRecord.fromJson({
      ...b.toJson(),
      'date': nd,
      'at': shIso(b.at),
      'no': '${nd.substring(2).replaceAll('-', '')}-$tail',
    });
  }
  for (var i = 0; i < s.purchases.length; i++) {
    final p = s.purchases[i];
    s.purchases[i] = PurchaseRecord.fromJson({
      ...p.toJson(),
      'date': shKey(p.date),
      'at': shIso(p.at),
    });
  }
  for (var i = 0; i < s.expenses.length; i++) {
    final e = s.expenses[i];
    s.expenses[i] = ExpenseRecord.fromJson({
      ...e.toJson(),
      'date': shKey(e.date),
      'at': shIso(e.at),
    });
  }
  for (var i = 0; i < s.shifts.length; i++) {
    final sh = s.shifts[i];
    s.shifts[i] = ShiftRecord.fromJson({
      ...sh.toJson(),
      'openedAt': shIso(sh.openedAt),
      if (sh.closedAt != null) 'closedAt': shIso(sh.closedAt!),
    });
  }
  return const SetupCrudResult.success('จำลองข้ามไปวันถัดไป (+1 วัน) แล้ว');
}
