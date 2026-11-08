import 'dart:async';
import 'dart:convert';

import 'package:app/core/data/local/local_db.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

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

/// How far the current send has got; [done] once it finished.
@immutable
class OutboxProgress {
  const new({
    required this.total,
    required this.bills,
    this.sent = 0,
    this.sentBills = 0,
    this.rejected = 0,
    this.done = false,
  });

  final int total;
  final int bills;
  final int sent;
  final int sentBills;
  final int rejected;
  final bool done;

  OutboxProgress _next({required bool bill, required bool ok}) =>
      OutboxProgress(
        total: total,
        bills: bills,
        sent: ok ? sent + 1 : sent,
        sentBills: ok && bill ? sentBills + 1 : sentBills,
        rejected: ok ? rejected : rejected + 1,
      );

  @override
  bool operator ==(Object other) =>
      other is OutboxProgress &&
      other.total == total &&
      other.bills == bills &&
      other.sent == sent &&
      other.sentBills == sentBills &&
      other.rejected == rejected &&
      other.done == done;

  @override
  int get hashCode =>
      Object.hash(total, bills, sent, sentBills, rejected, done);

  @override
  String toString() =>
      'OutboxProgress($sent/$total, bills $sentBills/$bills, '
      'rejected $rejected, done $done)';
}

/// Commands made while offline, kept in the browser's database and sent in
/// order once the connection is back.
class OutboxQueue {
  new(this._db, {required this.shopId});

  final LocalDb _db;
  final String shopId;
  Future<OutboxFlushResult>? _flushing;
  final ValueNotifier<OutboxProgress?> _progress =
      ValueNotifier<OutboxProgress?>(null);

  static const String _billFn = 'settle_bill';

  /// The send in progress or just finished; `null` when nothing was sent.
  ValueListenable<OutboxProgress?> get progress => _progress;

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

  /// The largest integer [param] among commands still waiting, or 0; used to
  /// continue receipt numbers after a restart while offline.
  Future<int> maxPendingInt(String param) async {
    final rows = await (_db.select(_db.outboxEntries)..where(_pending)).get();
    var max = 0;
    for (final r in rows) {
      final v = (jsonDecode(r.params) as Map<String, dynamic>)[param];
      if (v is int && v > max) max = v;
    }
    return max;
  }

  /// Emits how many waiting commands are bills whenever the queue changes.
  Stream<int> watchPendingBills() =>
      (_db.select(_db.outboxEntries)..where(_pending)).watch().map(
        (rows) => rows.where((r) => r.fn == _billFn).length,
      );

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
    if (entries.isEmpty) {
      return const OutboxFlushResult(sent: 0, rejected: 0, offline: false);
    }
    var progress = OutboxProgress(
      total: entries.length,
      bills: entries.where((e) => e.fn == _billFn).length,
    );
    _progress.value = progress;
    for (final e in entries) {
      final row = _db.update(_db.outboxEntries)
        ..where((t) => t.seq.equals(e.seq));
      final isBill = e.fn == _billFn;
      try {
        await send(e.fn, jsonDecode(e.params) as Map<String, dynamic>);
      } on OutboxOfflineException {
        await row.write(
          OutboxEntriesCompanion(attempts: Value(e.attempts + 1)),
        );
        // Still offline: the banner keeps showing what waits.
        _progress.value = null;
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
        progress = progress._next(bill: isBill, ok: false);
        _progress.value = progress;
        continue;
      }
      sent++;
      await (_db.delete(
        _db.outboxEntries,
      )..where((t) => t.seq.equals(e.seq))).go();
      progress = progress._next(bill: isBill, ok: true);
      _progress.value = progress;
    }
    _progress.value = OutboxProgress(
      total: progress.total,
      bills: progress.bills,
      sent: progress.sent,
      sentBills: progress.sentBills,
      rejected: progress.rejected,
      done: true,
    );
    return OutboxFlushResult(sent: sent, rejected: rejected, offline: false);
  }

  /// Forgets a finished send so the banner can hide.
  void clearProgress() {
    if (_progress.value?.done ?? false) _progress.value = null;
  }
}
