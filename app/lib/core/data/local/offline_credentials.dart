import 'dart:convert';
import 'dart:math';

import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/pin_hash.dart' as pin_hash;
import 'package:drift/drift.dart';

/// How an offline PIN check ended.
enum OfflinePinResult { success, invalid, locked, expired, unknown }

/// Result of [OfflineCredentials.verify]; [token] is set on success.
class OfflinePinCheck {
  const new(this.result, [this.token]);

  final OfflinePinResult result;
  final String? token;
}

/// Lets staff who signed in online on this device in the last 7 days sign in
/// with the same PIN while offline. Five wrong PINs lock for five minutes,
/// like the server.
class OfflineCredentials {
  new(
    this._db, {
    required this.shopId,
    Future<String> Function(String pin, String salt)? hash,
    DateTime Function()? clock,
  }) : _hash = hash ?? pin_hash.hashPin,
       _clock = clock ?? DateTime.now;

  static const int _maxAttempts = 5;
  static const Duration _lock = Duration(minutes: 5);

  final LocalDb _db;
  final String shopId;
  final Future<String> Function(String pin, String salt) _hash;
  final DateTime Function() _clock;

  /// Remembers [staffId]'s PIN check and offline token after an online
  /// sign-in, replacing the previous one.
  Future<void> save({
    required String staffId,
    required String pin,
    required String offlineToken,
    required DateTime expiresAt,
  }) async {
    final salt = base64.encode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    await _db
        .into(_db.offlineStaffCredentials)
        .insertOnConflictUpdate(
          OfflineStaffCredentialsCompanion.insert(
            staffId: staffId,
            shopId: shopId,
            salt: salt,
            pinHash: await _hash(pin, salt),
            offlineToken: offlineToken,
            expiresAt: expiresAt,
          ),
        );
  }

  /// Checks [pin] for [staffId] without the server.
  Future<OfflinePinCheck> verify(String staffId, String pin) async {
    final row =
        await (_db.select(_db.offlineStaffCredentials)..where(
              (t) => t.staffId.equals(staffId) & t.shopId.equals(shopId),
            ))
            .getSingleOrNull();
    if (row == null) return const OfflinePinCheck(OfflinePinResult.unknown);
    final now = _clock();
    if (!row.expiresAt.isAfter(now)) {
      return const OfflinePinCheck(OfflinePinResult.expired);
    }
    final lockedUntil = row.lockedUntil;
    if (lockedUntil != null && lockedUntil.isAfter(now)) {
      return const OfflinePinCheck(OfflinePinResult.locked);
    }
    final update = _db.update(_db.offlineStaffCredentials)
      ..where((t) => t.staffId.equals(staffId));
    if (await _hash(pin, row.salt) == row.pinHash) {
      await update.write(
        const OfflineStaffCredentialsCompanion(
          failedAttempts: Value(0),
          lockedUntil: Value(null),
        ),
      );
      return OfflinePinCheck(OfflinePinResult.success, row.offlineToken);
    }
    final failed = row.failedAttempts + 1;
    final locks = failed >= _maxAttempts;
    await update.write(
      OfflineStaffCredentialsCompanion(
        failedAttempts: Value(locks ? 0 : failed),
        lockedUntil: Value(locks ? now.add(_lock) : null),
      ),
    );
    return OfflinePinCheck(
      locks ? OfflinePinResult.locked : OfflinePinResult.invalid,
    );
  }
}
