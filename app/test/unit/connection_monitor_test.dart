import 'dart:async';

import 'package:app/core/data/local/connection_monitor.dart';
import 'package:app/core/data/local/outbox_queue.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ValueNotifier<bool> reachable;
  late StreamController<bool> network;
  late StreamController<int> pending;
  late ConnectionMonitor monitor;

  setUp(() {
    reachable = ValueNotifier<bool>(true);
    network = StreamController<bool>();
    pending = StreamController<int>();
    monitor = ConnectionMonitor(
      reachable: reachable,
      hasNetwork: network.stream,
      pendingCount: pending.stream,
    );
  });
  tearDown(() async {
    monitor.dispose();
    await network.close();
    await pending.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('online with nothing waiting by default', () {
    expect(monitor.status.value, const SyncStatus(online: true, pending: 0));
  });

  test('offline when the device loses its network', () async {
    // Act
    network.add(false);
    await settle();

    // Assert
    expect(monitor.status.value.online, isFalse);
  });

  test('offline when the server cannot be reached despite Wi-Fi', () async {
    // Act
    network.add(true);
    reachable.value = false;
    await settle();

    // Assert
    expect(monitor.status.value.online, isFalse);
  });

  test('counts commands waiting to be sent', () async {
    // Act
    pending.add(3);
    await settle();

    // Assert
    expect(monitor.status.value, const SyncStatus(online: true, pending: 3));
  });

  test('network back and server reached means online again', () async {
    // Arrange
    network.add(false);
    reachable.value = false;
    await settle();

    // Act
    network.add(true);
    reachable.value = true;
    await settle();

    // Assert
    expect(monitor.status.value.online, isTrue);
  });

  test('shows a finished send, then hides it after a while', () async {
    // Arrange
    final progress = ValueNotifier<OutboxProgress?>(null);
    final bills = StreamController<int>();
    final m = ConnectionMonitor(
      reachable: ValueNotifier<bool>(true),
      hasNetwork: const Stream<bool>.empty(),
      pendingCount: const Stream<int>.empty(),
      pendingBills: bills.stream,
      progress: progress,
      doneFor: const Duration(milliseconds: 50),
    );
    addTearDown(() async {
      m.dispose();
      await bills.close();
    });

    // Act & Assert: bills waiting, then sending, then done.
    bills.add(2);
    await settle();
    expect(m.status.value.pendingBills, 2);
    progress.value = const OutboxProgress(total: 3, bills: 2, sent: 1);
    expect(m.status.value.progress?.sent, 1);
    const done = OutboxProgress(
      total: 3,
      bills: 2,
      sent: 3,
      sentBills: 2,
      done: true,
    );
    progress.value = done;
    expect(m.status.value.progress, done);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(m.status.value.progress, isNull);
  });
}
