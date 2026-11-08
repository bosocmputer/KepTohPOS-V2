import 'dart:async';
import 'dart:convert';

import 'package:app/core/data/local/local_db.dart';
import 'package:drift/drift.dart';

/// Thrown by an [OutboxSender] when the server could not be reached; the
/// command stays queued for the next attempt.
class OutboxOfflineException implements Exception {
  const new();
}

/// Sends one queued command. Throwing [OutboxOfflineException] means "try
/// again later"; any other error means the server refused it.
typedef OutboxSender = Future<void> Function(
  String fn,
  Map<String, dynamic> params,
);

/// What one [OutboxQueue.flush] did.
class OutboxFlushResult {
  const new({
    required this.sent,
    required this.rejected,
    required this.offline,
  });

  final int sent;
  final int rejected;

  /// True when sending stopped because the connection dropped.
  final bool offline;
}

/// Commands made while offline, kept in the browser's database and sent in
/// order once the connection is back.
class OutboxQueue {
  new(this._db, {required this.shopId});

  final LocalDb _db;
  final String shopId;
  Future<OutboxFlushResult>? _flushing;

  Expression<bool> _pending(OutboxEntries t) =>
      t.shopId.equals(shopId) & t.rejected.equals(false);

  /// Queues [fn] with [params] under the command's own idempotency [id].
  Future<void> add({
    required String id,
    required String fn,
    required Map<String, dynamic> params,
    DateTime? now,
  }) async {
    await _db
        .into(_db.outboxEntries)
        .insert(
          OutboxEntriesCompanion.insert(
            id: id,
            shopId: shopId,
            fn: fn,
            params: jsonEncode(params),
            createdAt: now ?? DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Number of commands still waiting to be sent.
  Future<int> pendingCount() {
    final count = _db.outboxEntries.seq.count();
    final query = _db.selectOnly(_db.outboxEntries)
      ..addColumns(<Expression<Object>>[count])
      ..where(_pending(_db.outboxEntries));
    return query.getSingle().then((row) => row.read(count) ?? 0);
  }

  /// Emits [pendingCount] whenever the queue changes.
  Stream<int> watchPendingCount() => (_db.select(
    _db.outboxEntries,
  )..where(_pending)).watch().map((rows) => rows.length);

  /// Commands the server refused, oldest first, for someone to review.
  Future<List<OutboxEntry>> rejectedEntries() =>
      (_db.select(_db.outboxEntries)
            ..where((t) => t.shopId.equals(shopId) & t.rejected.equals(true))
            ..orderBy(<OrderClauseGenerator<OutboxEntries>>[
              (t) => OrderingTerm.asc(t.seq),
            ]))
          .get();

  /// Sends waiting commands in order. Only one flush runs at a time; a second
  /// call while one is running waits for the same result.
  Future<OutboxFlushResult> flush(OutboxSender send) =>
      _flushing ??= _flush(send).whenComplete(() => _flushing = null);

  Future<OutboxFlushResult> _flush(OutboxSender send) async {
    var sent = 0;
    var rejected = 0;
    final entries =
        await (_db.select(_db.outboxEntries)
              ..where(_pending)
              ..orderBy(<OrderClauseGenerator<OutboxEntries>>[
                (t) => OrderingTerm.asc(t.seq),
              ]))
            .get();
    for (final e in entries) {
      final row = _db.update(_db.outboxEntries)
        ..where((t) => t.seq.equals(e.seq));
      try {
        await send(e.fn, jsonDecode(e.params) as Map<String, dynamic>);
      } on OutboxOfflineException {
        await row.write(
          OutboxEntriesCompanion(attempts: Value(e.attempts + 1)),
        );
        return OutboxFlushResult(sent: sent, rejected: rejected, offline: true);
      } on Object catch (error) {
        rejected++;
        await row.write(
          OutboxEntriesCompanion(
            attempts: Value(e.attempts + 1),
            rejected: const Value(true),
            lastError: Value(error.toString()),
          ),
        );
        continue;
      }
      sent++;
      await (_db.delete(
        _db.outboxEntries,
      )..where((t) => t.seq.equals(e.seq))).go();
    }
    return OutboxFlushResult(sent: sent, rejected: rejected, offline: false);
  }
}
