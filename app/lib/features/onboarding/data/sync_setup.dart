import 'package:app/core/data/local/connection_monitor.dart';
import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/outbox_queue.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Opens the browser database, the outbox for [shopId] and the connection
/// monitor once the device is paired, and registers them for the app.
ConnectionMonitor startSync(DeviceSession session, String shopId) {
  if (sl.isRegistered<ConnectionMonitor>()) return sl<ConnectionMonitor>();
  final db = LocalDb();
  final queue = OutboxQueue(db, shopId: shopId);
  final monitor = ConnectionMonitor(
    reachable: session.reachable,
    hasNetwork: Connectivity().onConnectivityChanged.map(
      (r) => !r.contains(ConnectivityResult.none),
    ),
    pendingCount: queue.watchPendingCount(),
  );
  sl
    ..registerSingleton<LocalDb>(db, dispose: (d) => d.close())
    ..registerSingleton<OutboxQueue>(queue)
    ..registerSingleton<ConnectionMonitor>(
      monitor,
      dispose: (m) => m.dispose(),
    );
  return monitor;
}
