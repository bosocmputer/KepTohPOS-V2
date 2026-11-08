import 'dart:async';

import 'package:app/core/data/local/connection_monitor.dart';
import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/offline_credentials.dart';
import 'package:app/core/data/local/outbox_queue.dart';
import 'package:app/core/data/supabase/supabase_pos_repository.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Sends queued commands when the connection returns, and retries every
/// `interval` while anything waits; each retry also probes the server, which
/// matters when Wi-Fi is up but the internet is not.
class SyncEngine {
  new(
    this._repo,
    this._monitor, {
    Duration interval = const Duration(seconds: 15),
  }) {
    _monitor.status.addListener(_onStatus);
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  final SupabasePosRepository _repo;
  final ConnectionMonitor _monitor;
  late final Timer _timer;
  bool _wasOnline = true;

  void _onStatus() {
    final s = _monitor.status.value;
    if (s.online && !_wasOnline && s.pending > 0) unawaited(_flush());
    _wasOnline = s.online;
  }

  void _tick() {
    if (_monitor.status.value.pending > 0) unawaited(_flush());
  }

  Future<void> _flush() async {
    try {
      await _repo.flushOutbox();
    } on Object catch (e) {
      debugPrint('outbox flush failed: $e');
    }
  }

  void dispose() {
    _monitor.status.removeListener(_onStatus);
    _timer.cancel();
  }
}

/// Opens the browser database, the outbox and the connection monitor once
/// the device is paired, hands the outbox to [repo] and starts syncing.
ConnectionMonitor startSync(DeviceSession session, SupabasePosRepository repo) {
  if (sl.isRegistered<ConnectionMonitor>()) return sl<ConnectionMonitor>();
  final db = LocalDb();
  final queue = OutboxQueue(db, shopId: repo.shopId);
  final monitor = ConnectionMonitor(
    reachable: session.reachable,
    hasNetwork: Connectivity().onConnectivityChanged.map(
      (r) => !r.contains(ConnectivityResult.none),
    ),
    pendingCount: queue.watchPendingCount(),
  );
  repo
    ..outbox = queue
    ..credentials = OfflineCredentials(db, shopId: repo.shopId);
  sl
    ..registerSingleton<LocalDb>(db, dispose: (d) => d.close())
    ..registerSingleton<OutboxQueue>(queue)
    ..registerSingleton<ConnectionMonitor>(monitor, dispose: (m) => m.dispose())
    ..registerSingleton<SyncEngine>(
      SyncEngine(repo, monitor),
      dispose: (e) => e.dispose(),
    );
  return monitor;
}
