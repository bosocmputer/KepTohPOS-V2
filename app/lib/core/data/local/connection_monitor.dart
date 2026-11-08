import 'dart:async';

import 'package:flutter/foundation.dart';

/// What the sync banner shows: whether the server can be reached, and how
/// many commands made offline still wait to be sent.
@immutable
class SyncStatus {
  const new({required this.online, required this.pending});

  final bool online;
  final int pending;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus && other.online == online && other.pending == pending;

  @override
  int get hashCode => Object.hash(online, pending);

  @override
  String toString() => 'SyncStatus(online: $online, pending: $pending)';
}

/// Combines the device's network state, whether requests actually reach the
/// server, and the outbox size into one [status].
class ConnectionMonitor {
  new({
    required this._reachable,
    required Stream<bool> hasNetwork,
    required Stream<int> pendingCount,
  }) {
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
  final List<StreamSubscription<Object?>> _subs =
      <StreamSubscription<Object?>>[];
  final ValueNotifier<SyncStatus> _status = ValueNotifier<SyncStatus>(
    const SyncStatus(online: true, pending: 0),
  );
  bool _hasNetwork = true;
  int _pending = 0;

  /// The current state, for the banner and for starting a resend.
  ValueListenable<SyncStatus> get status => _status;

  void _update() => _status.value = SyncStatus(
    online: _hasNetwork && _reachable.value,
    pending: _pending,
  );

  void dispose() {
    _reachable.removeListener(_update);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _status.dispose();
  }
}
