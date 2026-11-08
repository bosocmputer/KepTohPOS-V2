import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/outbox_queue.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDb db;
  late OutboxQueue queue;
  final t0 = DateTime.utc(2026, 11, 8, 12);

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
    queue = OutboxQueue(db, shopId: 'shop-1');
  });
  tearDown(() => db.close());

  Future<void> addThree() async {
    for (final id in <String>['a', 'b', 'c']) {
      await queue.add(id: id, fn: 'send_round', params: {'k': id}, now: t0);
    }
  }

  test('sends pending commands in the order they were made', () async {
    // Arrange
    await addThree();
    final sent = <String>[];

    // Act
    final result = await queue.flush((fn, params) async {
      sent.add(params['k'] as String);
    });

    // Assert
    expect(sent, <String>['a', 'b', 'c']);
    expect(result.sent, 3);
    expect(await queue.pendingCount(), 0);
  });

  test('stops at the first offline failure and keeps the rest', () async {
    // Arrange
    await addThree();
    final sent = <String>[];

    // Act
    final result = await queue.flush((fn, params) async {
      if (params['k'] == 'b') throw const OutboxOfflineException();
      sent.add(params['k'] as String);
    });

    // Assert
    expect(sent, <String>['a']);
    expect(result.offline, isTrue);
    expect(await queue.pendingCount(), 2);
  });

  test('a refused command is set aside and does not block the queue', () async {
    // Arrange
    await addThree();
    final sent = <String>[];

    // Act
    final result = await queue.flush((fn, params) async {
      if (params['k'] == 'b') throw StateError('server said no');
      sent.add(params['k'] as String);
    });

    // Assert
    expect(sent, <String>['a', 'c']);
    expect(result.rejected, 1);
    expect(await queue.pendingCount(), 0);
    final refused = await queue.rejectedEntries();
    expect(refused.single.id, 'b');
    expect(refused.single.lastError, contains('server said no'));
  });

  test('adding the same command id twice keeps one entry', () async {
    // Act
    await queue.add(id: 'x', fn: 'settle_bill', params: {}, now: t0);
    await queue.add(id: 'x', fn: 'settle_bill', params: {}, now: t0);

    // Assert
    expect(await queue.pendingCount(), 1);
  });

  test('each shop only sees its own commands', () async {
    // Arrange
    await queue.add(id: 'mine', fn: 'f', params: {}, now: t0);
    final other = OutboxQueue(db, shopId: 'shop-2');

    // Act & Assert
    expect(await other.pendingCount(), 0);
    expect(await queue.pendingCount(), 1);
  });

  test('counts waiting bills and reports progress while sending', () async {
    // Arrange: two bills among three commands.
    await queue.add(id: 'r', fn: 'send_round', params: {'k': 'r'}, now: t0);
    await queue.add(id: 'b1', fn: 'settle_bill', params: {'k': 'b1'}, now: t0);
    await queue.add(id: 'b2', fn: 'settle_bill', params: {'k': 'b2'}, now: t0);
    expect(await queue.watchPendingBills().first, 2);
    final seen = <OutboxProgress?>[];
    queue.progress.addListener(() => seen.add(queue.progress.value));

    // Act
    await queue.flush((fn, params) async {});

    // Assert: started at 0/3, ended done with every bill sent.
    expect(seen.first, const OutboxProgress(total: 3, bills: 2));
    expect(
      queue.progress.value,
      const OutboxProgress(
        total: 3,
        bills: 2,
        sent: 3,
        sentBills: 2,
        done: true,
      ),
    );
    expect(await queue.watchPendingBills().first, 0);
  });

  test('a probe while still offline leaves no progress behind', () async {
    // Arrange
    await addThree();

    // Act
    await queue.flush(
      (fn, params) async => throw const OutboxOfflineException(),
    );

    // Assert
    expect(queue.progress.value, isNull);
  });
}
