import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/offline_credentials.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDb db;
  late OfflineCredentials store;
  var now = DateTime.utc(2026, 11, 8, 12);

  // A fast stand-in for the browser's PBKDF2, enough to compare PINs.
  Future<String> fakeHash(String pin, String salt) async => '$salt:$pin';

  setUp(() async {
    now = DateTime.utc(2026, 11, 8, 12);
    db = LocalDb(NativeDatabase.memory());
    store = OfflineCredentials(
      db,
      shopId: 'shop-1',
      hash: fakeHash,
      clock: () => now,
    );
    await store.save(
      staffId: 'st1',
      pin: '1234',
      offlineToken: 'tok-1',
      expiresAt: now.add(const Duration(days: 7)),
    );
  });
  tearDown(() => db.close());

  test('the right PIN within 7 days gives the offline token', () async {
    final r = await store.verify('st1', '1234');
    expect(r.result, OfflinePinResult.success);
    expect(r.token, 'tok-1');
  });

  test('a wrong PIN, an unknown person or an old sign-in is refused', () async {
    expect(
      (await store.verify('st1', '0000')).result,
      OfflinePinResult.invalid,
    );
    expect(
      (await store.verify('st9', '1234')).result,
      OfflinePinResult.unknown,
    );
    now = now.add(const Duration(days: 7, minutes: 1));
    expect(
      (await store.verify('st1', '1234')).result,
      OfflinePinResult.expired,
    );
  });

  test('five wrong PINs lock the person for five minutes', () async {
    // Act
    for (var i = 0; i < 5; i++) {
      await store.verify('st1', '9999');
    }

    // Assert: even the right PIN waits until the lock ends.
    expect((await store.verify('st1', '1234')).result, OfflinePinResult.locked);
    now = now.add(const Duration(minutes: 5, seconds: 1));
    expect(
      (await store.verify('st1', '1234')).result,
      OfflinePinResult.success,
    );
  });

  test('the PIN itself is never stored', () async {
    final rows = await db.select(db.offlineStaffCredentials).get();
    expect(rows.single.pinHash, isNot('1234'));
    expect(rows.single.salt, isNotEmpty);
  });
}
