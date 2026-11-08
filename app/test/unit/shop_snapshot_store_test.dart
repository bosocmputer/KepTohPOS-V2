import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/outbox_queue.dart';
import 'package:app/core/data/local/shop_snapshot_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDb db;
  late ShopSnapshotStore store;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
    store = ShopSnapshotStore(db);
  });
  tearDown(() => db.close());

  Map<String, dynamic> stateWithCosts() => <String, dynamic>{
    'addons': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'a1', 'price': 4500, 'cost': 3000},
    ],
    'ingredients': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'i1', 'lastCost': 18000},
    ],
    'sales': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'b1',
        'total': 59800,
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'โค้ก', 'price': 4500, 'cost': 3000},
        ],
      },
    ],
    'expenses': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'e1', 'amount': 45000, 'note': 'น้ำแข็ง'},
    ],
    'purchases': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'p1',
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{'ingId': 'i1', 'qty': 2, 'total': 36000},
        ],
      },
    ],
    'fixedCosts': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'f1', 'amount': 1500000},
    ],
    'initialStock': <String, dynamic>{
      'i1': <String, dynamic>{'qty': 5, 'cost': 18000},
    },
  };

  test('saved snapshots carry no cost or expense amounts', () {
    // Act
    final s = stripCosts(stateWithCosts());

    // Assert: what staff need to sell stays; every cost is gone.
    final addon = (s['addons'] as List<dynamic>).single as Map<String, dynamic>;
    expect(addon['price'], 4500);
    expect(addon['cost'], 0);
    expect(((s['ingredients'] as List<dynamic>).single as Map)['lastCost'], 0);
    final bill = (s['sales'] as List<dynamic>).single as Map<String, dynamic>;
    expect(bill['total'], 59800);
    expect((bill['lines'] as List<dynamic>).single, isNot(contains('cost')));
    expect(((s['expenses'] as List<dynamic>).single as Map)['amount'], 0);
    expect(((s['expenses'] as List<dynamic>).single as Map)['note'], 'น้ำแข็ง');
    final line =
        (((s['purchases'] as List<dynamic>).single as Map)['lines'] as List)
                .single
            as Map;
    expect(line['total'], 0);
    expect(line['qty'], 2);
    expect(s['fixedCosts'], isEmpty);
    expect(s['initialStock'], isEmpty);
    // The input is not changed.
    expect(((stateWithCosts()['addons'] as List).single as Map)['cost'], 3000);
  });

  test('keeps the latest snapshot and reads it back', () async {
    // Act
    await store.save('shop-1', <String, dynamic>{'v': 1});
    await store.save('shop-1', <String, dynamic>{'v': 2});

    // Assert
    final latest = await store.latest();
    expect(latest!.shopId, 'shop-1');
    expect(latest.data['v'], 2);
  });

  test('nothing saved means no snapshot', () async {
    expect(await store.latest(), isNull);
  });

  test('the highest receipt number still waiting in the outbox', () async {
    // Arrange
    final queue = OutboxQueue(db, shopId: 'shop-1');
    await queue.add(id: '1', fn: 'settle_bill', params: {'p_seq': 7});
    await queue.add(id: '2', fn: 'send_round', params: {});
    await queue.add(id: '3', fn: 'settle_bill', params: {'p_seq': 9});

    // Act & Assert
    expect(await queue.maxPendingInt('p_seq'), 9);
    expect(await OutboxQueue(db, shopId: 'x').maxPendingInt('p_seq'), 0);
  });
}
