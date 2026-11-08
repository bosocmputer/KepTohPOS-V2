import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/outbox_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The browser database really opens through drift's worker and the
/// sqlite3.wasm in web/, and keeps queued commands. Covers OF-01 groundwork.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('outbox persists in the browser database', (tester) async {
    // Arrange
    final db = LocalDb();
    final shop = 'e2e-${DateTime.now().millisecondsSinceEpoch}';
    final queue = OutboxQueue(db, shopId: shop);

    // Act
    await queue.add(id: '$shop-1', fn: 'send_round', params: {'n': 1});
    await queue.add(id: '$shop-2', fn: 'settle_bill', params: {'n': 2});
    final sent = <String>[];
    final before = await queue.pendingCount();
    final result = await queue.flush((fn, params) async => sent.add(fn));

    // Assert
    expect(before, 2);
    expect(sent, <String>['send_round', 'settle_bill']);
    expect(result.sent, 2);
    expect(await queue.pendingCount(), 0);
    await db.close();
  });
}
