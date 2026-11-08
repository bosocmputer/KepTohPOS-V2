import 'dart:async';

import 'package:app/core/data/local/connection_monitor.dart';
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
}
