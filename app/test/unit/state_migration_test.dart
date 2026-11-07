import 'package:app/domain/models.dart';
import 'package:app/domain/state_migration.dart';
import 'package:flutter_test/flutter_test.dart';

/// State as saved by the current production app (`version: 2`, baht).
Map<String, dynamic> legacyState() => <String, dynamic>{
  'version': 2,
  'startDate': '2026-11-01',
  'shop': <String, dynamic>{'name': 'ร้านทดสอบ', 'defaultFloat': 1000},
  'packages': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'pk1',
      'name': 'หมู',
      'adultPrice': 199,
      'childPrice': 99.5,
    },
  ],
  'addons': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'ad1',
      'name': 'น้ำ',
      'price': 15,
      'cost': 6.25,
      'stock': 96,
    },
  ],
  'suppliers': <Map<String, dynamic>>[],
  'ingredients': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'i1',
      'name': 'หมู',
      'unit': 'กก.',
      'lastCost': 185,
      'par': 14.5,
      'use': 0.11,
    },
  ],
  'tables': <Map<String, dynamic>>[],
  'staff': <Map<String, dynamic>>[],
  'payments': <Map<String, dynamic>>[],
  'expenseTypes': <Map<String, dynamic>>[],
  'fixedCosts': <Map<String, dynamic>>[
    <String, dynamic>{'id': 'f1', 'name': 'ค่าเช่า', 'amount': 15000},
  ],
  'sales': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'b1',
      'no': '261107-001',
      'date': '2026-11-07',
      'at': '2026-11-07T12:00:00.000Z',
      'subtotal': 213.5,
      'service': 0,
      'vat': 14.95,
      'rounding': -0.45,
      'total': 228,
      'received': 500,
      'change': 272,
      'heads': <String, dynamic>{'a': 1, 'c': 0, 'f': 0},
      'lines': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'buffet',
          'name': 'หมู',
          'qty': 1,
          'price': 199,
        },
        <String, dynamic>{
          'type': 'addon',
          'id': 'ad1',
          'name': 'น้ำ',
          'qty': 1,
          'price': 14.5,
          'cost': 6.25,
        },
      ],
    },
  ],
  'purchases': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'p1',
      'date': '2026-11-07',
      'at': '2026-11-07T01:00:00.000Z',
      'lines': <Map<String, dynamic>>[
        <String, dynamic>{'ingId': 'i1', 'qty': 2.5, 'total': 462.5},
      ],
    },
  ],
  'shifts': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'sh1',
      'staffId': 'st1',
      'openedAt': '2026-11-07T01:00:00.000Z',
      'floatAmount': 1000,
      'closedAt': '2026-11-07T14:00:00.000Z',
      'counted': 1228.75,
    },
    <String, dynamic>{
      'id': 'sh2',
      'staffId': 'st1',
      'openedAt': '2026-11-08T01:00:00.000Z',
      'float': 500,
    },
  ],
  'initialStock': <String, dynamic>{
    'i1': <String, dynamic>{'qty': 3.5, 'cost': 180.5},
  },
  'expenses': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'e1',
      'date': '2026-11-07',
      'at': '2026-11-07T02:00:00.000Z',
      'typeId': 'et1',
      'amount': 420.25,
    },
  ],
};

void main() {
  group('PosState.fromJson with version 2 (baht) data', () {
    test('converts every recorded amount to satang', () {
      // Act
      final s = PosState.fromJson(legacyState());

      // Assert
      expect(s.version, kPosStateVersion);
      expect(s.shop.defaultFloat, 100000);
      expect(s.packages.single.adultPrice, 19900);
      expect(s.packages.single.childPrice, 9950);
      expect(s.addons.single.price, 1500);
      expect(s.addons.single.cost, 625);
      expect(s.ingredients.single.lastCost, 18500);
      expect(s.fixedCosts.single.amount, 1500000);
      expect(s.expenses.single.amount, 42025);
      expect(s.shifts.first.floatAmount, 100000);
      expect(s.shifts.first.counted, 122875);
      expect(s.shifts.last.floatAmount, 50000);
      expect(s.initialStock['i1']!.cost, 18050);
      expect(s.purchases.single.lines.single.total, 46250);

      final bill = s.sales.single;
      expect(bill.subtotal, 21350);
      expect(bill.vat, 1495);
      expect(bill.rounding, -45);
      expect(bill.total, 22800);
      expect(bill.received, 50000);
      expect(bill.change, 27200);
      expect(bill.lines.last.price, 1450);
      expect(bill.lines.last.cost, 625);
    });

    test('keeps non-money values unchanged', () {
      // Act
      final s = PosState.fromJson(legacyState());

      // Assert
      expect(s.addons.single.stock, 96);
      expect(s.ingredients.single.par, 14.5);
      expect(s.ingredients.single.use, 0.11);
      expect(s.initialStock['i1']!.qty, 3.5);
      expect(s.purchases.single.lines.single.qty, 2.5);
      expect(s.sales.single.lines.first.qty, 1);
    });

    test('treats a missing version as legacy baht data', () {
      // Arrange
      final raw = legacyState()..remove('version');

      // Act
      final s = PosState.fromJson(raw);

      // Assert
      expect(s.packages.single.adultPrice, 19900);
    });

    test('saving then loading does not multiply amounts again', () {
      // Arrange
      final migrated = PosState.fromJson(legacyState());

      // Act
      final reloaded = PosState.fromJson(migrated.toJson());
      final twice = migrateStateJson(migrateStateJson(legacyState()));

      // Assert
      expect(reloaded.sales.single.total, 22800);
      expect(reloaded.packages.single.adultPrice, 19900);
      expect((twice['shop'] as Map<String, dynamic>)['defaultFloat'], 100000);
    });

    test('does not modify the input map', () {
      // Arrange
      final raw = legacyState();

      // Act
      migrateStateJson(raw);

      // Assert
      expect(raw['version'], 2);
      expect((raw['shop'] as Map<String, dynamic>)['defaultFloat'], 1000);
    });

    test('accepts minimal legacy data without optional lists', () {
      // Act
      final s = PosState.fromJson(<String, dynamic>{'version': 2});

      // Assert
      expect(s.version, kPosStateVersion);
      expect(s.sales, isEmpty);
    });
  });
}
