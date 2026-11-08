import 'dart:async';

import 'package:app/core/data/local/outbox_queue.dart';
import 'package:flutter/foundation.dart';

/// What the sync banner shows: whether the server can be reached, what
/// still waits (and how many of those are bills), and a send in progress or
/// just finished.
@immutable
class SyncStatus {
  const new({
    required this.online,
    required this.pending,
    this.pendingBills = 0,
    this.progress,
  });

  final bool online;
  final int pending;
  final int pendingBills;
  final OutboxProgress? progress;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.online == online &&
      other.pending == pending &&
      other.pendingBills == pendingBills &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(online, pending, pendingBills, progress);

  @override
  String toString() =>
      'SyncStatus(online: $online, pending: $pending, '
      'bills: $pendingBills, progress: $progress)';
}

/// Combines the device's network state, whether requests actually reach the
/// server, and the outbox size into one [status].
class ConnectionMonitor {
  new({
    required this._reachable,
    required Stream<bool> hasNetwork,
    required Stream<int> pendingCount,
    Stream<int>? pendingBills,
    this._progress,
    this.doneFor = const Duration(seconds: 6),
  }) {
    _progress?.addListener(_onProgress);
    if (pendingBills != null) {
      _subs.add(
        pendingBills.listen((v) {
          _pendingBills = v;
          _update();
        }),
      );
    }
    _reachable.addListener(_update);
    _subs
      ..add(
        hasNetwork.listen((v) {
          _hasNetwork = v;
          _update();
        }),
      )
      ..add(
        pendingCount.listen((v) {
          _pending = v;
          _update();
        }),
      );
  }

  final ValueListenable<bool> _reachable;
  final ValueListenable<OutboxProgress?>? _progress;

  /// How long a finished send stays on the banner.
  final Duration doneFor;
  int _pendingBills = 0;
  OutboxProgress? _expired;
  Timer? _doneTimer;
  final List<StreamSubscription<Object?>> _subs =
      <StreamSubscription<Object?>>[];
  final ValueNotifier<SyncStatus> _status = ValueNotifier<SyncStatus>(
    const SyncStatus(online: true, pending: 0),
  );
  bool _hasNetwork = true;
  int _pending = 0;

  /// The current state, for the banner and for starting a resend.
  ValueListenable<SyncStatus> get status => _status;

  void _onProgress() {
    final p = _progress?.value;
    if (p != null && p.done) {
      _doneTimer?.cancel();
      _doneTimer = Timer(doneFor, () {
        _expired = p;
        _update();
      });
    }
    _update();
  }

  void _update() {
    final p = _progress?.value;
    _status.value = SyncStatus(
      online: _hasNetwork && _reachable.value,
      pending: _pending,
      pendingBills: _pendingBills,
      progress: identical(p, _expired) ? null : p,
    );
  }

  void dispose() {
    _reachable.removeListener(_update);
    _progress?.removeListener(_onProgress);
    _doneTimer?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _status.dispose();
  }
}
