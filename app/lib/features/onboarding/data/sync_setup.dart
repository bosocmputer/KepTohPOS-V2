import 'dart:async';

import 'package:app/core/data/local/connection_monitor.dart';
import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/offline_credentials.dart';
import 'package:app/core/data/local/outbox_queue.dart';
import 'package:app/core/data/local/shop_snapshot_store.dart';
import 'package:app/core/data/supabase/supabase_pos_repository.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/sync/realtime_sync.dart';
import 'package:app/core/sync/sync_center.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Sends queued commands when the connection returns, and retries every
/// `interval` while anything waits; each retry also probes the server, which
/// matters when Wi-Fi is up but the internet is not.
class SyncEngine {
  new(
    this._repo,
    this._monitor,
    this._snapshots, {
    Duration interval = const Duration(seconds: 15),
  }) {
    _monitor.status.addListener(_onStatus);
    _timer = Timer.periodic(interval, (_) => _tick());
    // Keep the latest shop data so the app can start offline next time.
    unawaited(_save());
    _changes = _repo.stream.listen((_) {
      _saveSoon?.cancel();
      _saveSoon = Timer(const Duration(seconds: 1), () => unawaited(_save()));
    });
  }

  final SupabasePosRepository _repo;
  final ConnectionMonitor _monitor;
  final ShopSnapshotStore _snapshots;
  late final Timer _timer;
  late final StreamSubscription<Object?> _changes;
  Timer? _saveSoon;
  bool _wasOnline = true;

  Future<void> _save() async {
    try {
      await _snapshots.save(_repo.shopId, _repo.toSnapshot());
    } on Object catch (e) {
      debugPrint('snapshot save failed: $e');
    }
  }

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
    _saveSoon?.cancel();
    unawaited(_changes.cancel());
  }
}

/// Opens the browser database, the outbox and the connection monitor once
/// the device is paired, hands the outbox to [repo] and starts syncing.
ConnectionMonitor startSync(
  DeviceSession session,
  SupabasePosRepository repo, {
  LocalDb? db,
}) {
  if (sl.isRegistered<ConnectionMonitor>()) return sl<ConnectionMonitor>();
  final localDb = db ?? LocalDb();
  final queue = OutboxQueue(localDb, shopId: repo.shopId);
  final monitor = ConnectionMonitor(
    reachable: session.reachable,
    hasNetwork: Connectivity().onConnectivityChanged.map(
      (r) => !r.contains(ConnectivityResult.none),
    ),
    pendingCount: queue.watchPendingCount(),
    pendingBills: queue.watchPendingBills(),
    progress: queue.progress,
  );
  repo
    ..outbox = queue
    ..credentials = OfflineCredentials(localDb, shopId: repo.shopId);
  sl
    ..registerSingleton<LocalDb>(localDb, dispose: (d) => d.close())
    ..registerSingleton<OutboxQueue>(queue)
    ..registerSingleton<ConnectionMonitor>(monitor, dispose: (m) => m.dispose())
    ..registerSingleton<SyncEngine>(
      SyncEngine(repo, monitor, ShopSnapshotStore(localDb)),
      dispose: (e) => e.dispose(),
    )
    ..registerSingleton<SyncCenter>(
      SyncCenter(
        queue: queue,
        monitor: monitor,
        sendNow: repo.flushOutbox,
        shop: () => repo.state,
      ),
      dispose: (c) => c.dispose(),
    )
    // Other devices' changes arrive as a signal; reload skips while the outbox
    // still holds unsent commands.
    ..registerSingleton<RealtimeSync>(
      RealtimeSync.shop(
        session.device,
        repo.shopId,
        () => session.quietly(repo.reload),
      ),
      dispose: (r) => r.dispose(),
    );
  return monitor;
}

/// The shop as last saved on this device, for starting without a
/// connection; `null` when nothing was saved yet. Receipt numbering resumes
/// after the highest number still waiting to be sent.
Future<SupabasePosRepository?> restoreOffline(
  DeviceSession session,
  LocalDb db,
) async {
  final snap = await ShopSnapshotStore(db).latest();
  if (snap == null) return null;
  final repo = SupabasePosRepository.restore(
    deviceClient: session.device,
    ownerClient: session.owner,
    shopId: snap.shopId,
    data: snap.data,
  );
  final queued = await OutboxQueue(
    db,
    shopId: snap.shopId,
  ).maxPendingInt('p_seq');
  if (queued > repo.receiptSeq) repo.receiptSeq = queued;
  return repo;
}
