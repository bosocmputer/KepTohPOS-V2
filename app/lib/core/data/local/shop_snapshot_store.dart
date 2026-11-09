import 'dart:convert';

import 'package:app/core/data/local/local_db.dart';
import 'package:drift/drift.dart';

/// A copy of [state] without costs, expense amounts or purchase totals, so a
/// snapshot kept in the browser never shows money staff may not see.
Map<String, dynamic> stripCosts(Map<String, dynamic> state) {
  final s = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
  Iterable<Map<String, dynamic>> rows(Object? list) =>
      (list as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();
  for (final a in rows(s['addons'])) {
    a['cost'] = 0;
  }
  for (final i in rows(s['ingredients'])) {
    i['lastCost'] = 0;
  }
  for (final b in rows(s['sales'])) {
    for (final l in rows(b['lines'])) {
      l.remove('cost');
    }
  }
  for (final t
      in (s['dailyTotals'] as Map<String, dynamic>? ?? const {}).values) {
    (t as Map<String, dynamic>)['addonCost'] = null;
  }
  for (final a in rows(s['addonSalesBefore'])) {
    a['cost'] = null;
  }
  for (final e in rows(s['expenses'])) {
    e['amount'] = 0;
  }
  for (final p in rows(s['purchases'])) {
    if (p.containsKey('total')) p['total'] = 0;
    for (final l in rows(p['lines'])) {
      l['total'] = 0;
    }
  }
  s['fixedCosts'] = <dynamic>[];
  s['initialStock'] = <String, dynamic>{};
  return s;
}

/// The last saved data of a shop.
class ShopSnapshot {
  const new(this.shopId, this.data, this.savedAt);

  final String shopId;
  final Map<String, dynamic> data;
  final DateTime savedAt;
}

/// Keeps the shop's latest data in the browser so the app can start without
/// a connection.
class ShopSnapshotStore {
  new(this._db);

  final LocalDb _db;

  Future<void> save(String shopId, Map<String, dynamic> data) => _db
      .into(_db.shopSnapshots)
      .insertOnConflictUpdate(
        ShopSnapshotsCompanion.insert(
          shopId: shopId,
          json: jsonEncode(data),
          savedAt: DateTime.now(),
        ),
      );

  /// The most recently saved snapshot, or `null` if there is none.
  Future<ShopSnapshot?> latest() async {
    final row =
        await (_db.select(_db.shopSnapshots)
              ..orderBy(<OrderClauseGenerator<ShopSnapshots>>[
                (t) => OrderingTerm.desc(t.savedAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return ShopSnapshot(
      row.shopId,
      jsonDecode(row.json) as Map<String, dynamic>,
      row.savedAt,
    );
  }
}
