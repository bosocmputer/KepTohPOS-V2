import 'dart:async';

import 'package:app/core/sync/realtime_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const wait = Duration(milliseconds: 20);

  test('a burst of signals gives one call after the quiet period', () async {
    final signals = StreamController<void>();
    var calls = 0;
    final sync = RealtimeSync(
      signals.stream,
      () async => calls++,
      debounce: wait,
    );
    signals
      ..add(null)
      ..add(null)
      ..add(null);
    await Future<void>.delayed(wait ~/ 2);
    expect(calls, 0);
    await Future<void>.delayed(wait * 3);
    expect(calls, 1);
    signals.add(null);
    await Future<void>.delayed(wait * 3);
    expect(calls, 2);
    sync.dispose();
    await signals.close();
  });

  test('dispose cancels a pending call', () async {
    final signals = StreamController<void>();
    var calls = 0;
    RealtimeSync(signals.stream, () async => calls++, debounce: wait).dispose();
    signals.add(null);
    await Future<void>.delayed(wait * 3);
    expect(calls, 0);
    await signals.close();
  });

  test('a failing callback does not stop later signals', () async {
    final signals = StreamController<void>();
    var calls = 0;
    final sync = RealtimeSync(signals.stream, () async {
      calls++;
      throw StateError('offline');
    }, debounce: wait);
    signals.add(null);
    await Future<void>.delayed(wait * 3);
    signals.add(null);
    await Future<void>.delayed(wait * 3);
    expect(calls, 2);
    sync.dispose();
    await signals.close();
  });
}
