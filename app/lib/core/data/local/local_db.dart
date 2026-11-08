import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_db.g.dart';

/// Server calls made while offline, sent in [seq] order once back online.
/// [id] is the command's own idempotency id, so a resend never doubles it.
class OutboxEntries extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get id => text().unique()();
  TextColumn get shopId => text()();
  TextColumn get fn => text()();
  TextColumn get params => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  /// Set when the server refused the command; it stays for review instead of
  /// blocking the commands behind it.
  BoolColumn get rejected => boolean().withDefault(const Constant(false))();
}

/// The last shop data seen online, to start the app without a connection.
class ShopSnapshots extends Table {
  TextColumn get shopId => text()();
  TextColumn get json => text()();
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{shopId};
}

/// SQLite kept in the browser (OPFS or IndexedDB), through drift's web worker.
@DriftDatabase(tables: <Type>[OutboxEntries, ShopSnapshots])
class LocalDb extends _$LocalDb {
  new([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() => driftDatabase(
    name: 'keptoh',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
