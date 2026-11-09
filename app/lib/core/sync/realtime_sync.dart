import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls `onChange` once things settle after the server says the shop's data
/// changed (a burst of signals gives one call). The signal carries no data;
/// the callback reloads it.
class RealtimeSync {
  new(
    Stream<void> signals,
    this._onChange, {
    this.debounce = const Duration(milliseconds: 500),
  }) {
    _sub = signals.listen((_) {
      _timer?.cancel();
      _timer = Timer(debounce, _fire);
    });
  }

  /// Listens to this shop's private channel on [client]. Signals stop and the
  /// channel closes when [dispose] is called or the client signs out.
  factory shop(
    SupabaseClient client,
    String shopId,
    Future<void> Function() onChange,
  ) {
    return RealtimeSync(_shopSignals(client, shopId), onChange);
  }

  final Future<void> Function() _onChange;
  final Duration debounce;
  late final StreamSubscription<void> _sub;
  Timer? _timer;
  bool _disposed = false;

  Future<void> _fire() async {
    if (_disposed) return;
    try {
      await _onChange();
    } on Object catch (e) {
      debugPrint('realtime reload failed: $e');
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_sub.cancel());
  }
}

/// One event per `changed` broadcast on `shop:<shopId>`. Resubscribes after a
/// channel error or timeout, and when the token is renewed.
Stream<void> _shopSignals(SupabaseClient client, String shopId) {
  final out = StreamController<void>();
  RealtimeChannel? channel;
  Timer? retry;
  StreamSubscription<AuthState>? auth;
  // A client built with `accessToken` (the paired device) has no `auth`;
  // realtime then fetches the token itself through that callback.
  final customToken = client.accessToken != null;

  Future<void> open() async {
    retry?.cancel();
    final old = channel;
    channel = null;
    if (old != null) await client.removeChannel(old);
    if (out.isClosed) return;
    if (customToken) {
      await client.realtime.setAuth(null);
    } else {
      final token = client.auth.currentSession?.accessToken;
      if (token == null) return;
      await client.realtime.setAuth(token);
    }
    channel = client
        .channel(
          'shop:$shopId',
          opts: const RealtimeChannelConfig(private: true),
        )
        .onBroadcast(event: 'changed', callback: (_) => out.add(null))
        .subscribe((status, _) {
          if (out.isClosed) return;
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            retry = Timer(const Duration(seconds: 5), () => unawaited(open()));
          }
        });
  }

  out
    ..onListen = () {
      unawaited(open());
      if (customToken) return;
      auth = client.auth.onAuthStateChange.listen((s) {
        if (s.event == AuthChangeEvent.signedOut) {
          unawaited(out.close());
        } else if (s.event == AuthChangeEvent.tokenRefreshed ||
            s.event == AuthChangeEvent.signedIn) {
          unawaited(open());
        }
      });
    }
    ..onCancel = () async {
      retry?.cancel();
      await auth?.cancel();
      final c = channel;
      if (c != null) await client.removeChannel(c);
      if (!out.isClosed) await out.close();
    };
  return out.stream;
}
