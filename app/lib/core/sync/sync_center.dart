import 'dart:async';
import 'dart:convert';

import 'package:app/core/data/local/connection_monitor.dart';
import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/outbox_queue.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/foundation.dart';

/// Where one bill stands in the outbox, for the badge on the bills page.
enum BillSync { waiting, refused }

/// One place the screens read what is still waiting to reach the server,
/// and from which a user can send now or retry refused commands.
class SyncCenter {
  new({
    required this.queue,
    required this.monitor,
    required this._sendNow,
    required this._shop,
    Stream<List<OutboxEntry>>? entries,
  }) {
    _sub = (entries ?? queue.watchAll()).listen((v) => _entries.value = v);
  }

  /// The registered center, or `null` in mock mode and before pairing.
  static SyncCenter? get maybe =>
      sl.isRegistered<SyncCenter>() ? sl<SyncCenter>() : null;

  /// Waiting this long means the 7-day offline sign-in may run out first.
  static const Duration staleAfter = Duration(days: 3);

  final OutboxQueue queue;
  final ConnectionMonitor monitor;
  final Future<void> Function() _sendNow;
  final PosState Function() _shop;
  late final StreamSubscription<List<OutboxEntry>> _sub;
  final ValueNotifier<List<OutboxEntry>> _entries =
      ValueNotifier<List<OutboxEntry>>(const <OutboxEntry>[]);
  bool _sending = false;

  /// Every command not yet accepted, oldest first.
  ValueListenable<List<OutboxEntry>> get entries => _entries;
  ValueListenable<SyncStatus> get status => monitor.status;
  ValueListenable<DateTime?> get lastSynced => queue.lastSynced;

  /// The shop as this device sees it, to name bills and tables.
  PosState get shop => _shop();

  /// Bills that are still waiting or were refused, by bill id.
  Map<String, BillSync> get bills {
    final out = <String, BillSync>{};
    for (final e in _entries.value) {
      final id = billIdOf(e);
      if (id != null) {
        out[id] = e.rejected ? BillSync.refused : BillSync.waiting;
      }
    }
    return out;
  }

  /// When the oldest waiting (not refused) command was made.
  DateTime? get oldestWaiting {
    for (final e in _entries.value) {
      if (!e.rejected) return e.createdAt;
    }
    return null;
  }

  bool isStale(DateTime now) {
    final oldest = oldestWaiting;
    return oldest != null && now.difference(oldest) > staleAfter;
  }

  /// Tries to send everything now; a second tap while sending is ignored.
  Future<void> sendNow() async {
    if (_sending) return;
    _sending = true;
    try {
      await _sendNow();
    } on Object catch (e) {
      debugPrint('send now failed: $e');
    } finally {
      _sending = false;
    }
  }

  /// Puts refused commands back in line and sends them again.
  Future<void> retryRefused() async {
    await queue.retryRejected();
    await sendNow();
  }

  /// The bill a command is about, or `null` when it is not about a bill.
  static String? billIdOf(OutboxEntry e) =>
      e.fn == 'settle_bill' || e.fn == 'void_bill'
      ? (jsonDecode(e.params) as Map<String, dynamic>)['p_bill_id'] as String?
      : null;

  void dispose() {
    unawaited(_sub.cancel());
    _entries.dispose();
  }
}
