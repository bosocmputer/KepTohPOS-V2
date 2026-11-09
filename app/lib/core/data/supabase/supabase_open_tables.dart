import 'package:app/core/data/supabase/supabase_row_mappers.dart';
import 'package:app/domain/models.dart';

/// Rebuilds the occupied tables from open sessions and their rounds/bills.
({Map<String, OpenTableState> tables, Map<String, String> sessions})
openTablesFrom({
  required List<Row> sessions,
  required List<Row> rounds,
  required List<Row> adjustments,
  required Set<String> settled,
  required List<Row> bills,
}) {
  final tables = <String, OpenTableState>{};
  final bySession = <String, String>{};
  for (final s in sessions.where((x) => x['closed_at'] == null)) {
    final id = s['id'] as String;
    final tableId = s['table_id'] as String;
    final sessionRounds = rounds.where((r) => r['session_id'] == id);
    final sessionAdjusts = adjustments.where((j) => j['session_id'] == id);
    final sessionBills = bills.where((b) => b['session_id'] == id);

    // Same running total as openOrAdd/adjustSent/voidBill in the domain.
    var a = 0;
    var c = 0;
    var f = 0;
    void add(Row r, int sign) {
      a += sign * (r['heads_a'] as int);
      c += sign * (r['heads_c'] as int);
      f += sign * (r['heads_f'] as int);
    }

    final isAfter = s['timing'] == 'after';
    if (isAfter) {
      for (final r in sessionRounds) {
        add(r, 1);
      }
      for (final j in sessionAdjusts.where((x) => x['kind'] == 'head')) {
        final qty = j['qty'] as int;
        switch (j['key']) {
          case 'a':
            a -= qty;
          case 'c':
            c -= qty;
          case 'f':
            f -= qty;
        }
      }
    } else {
      for (final b in sessionBills.where((x) => x['voided'] != true)) {
        add(b, 1);
      }
    }

    tables[tableId] = OpenTableState(
      openedAt: s['opened_at'] as String,
      packageId: s['package_id'] as String,
      timing: s['timing'] as String,
      notes: s['notes'] as String,
      billIds: sessionBills.map((b) => b['id'] as String).toList(),
      heads: HeadsCount(a: a < 0 ? 0 : a, c: c < 0 ? 0 : c, f: f < 0 ? 0 : f),
      rounds: sessionRounds
          .where((r) => !settled.contains(r['id']))
          .map(roundFromRow)
          .toList(),
      adjusts: sessionAdjusts
          .where((j) => !settled.contains(j['id']))
          .map(adjustmentFromRow)
          .toList(),
      log: sessionAdjusts
          .where((j) => settled.contains(j['id']))
          .map(adjustmentFromRow)
          .toList(),
    );
    bySession[tableId] = id;
  }
  return (tables: tables, sessions: bySession);
}
