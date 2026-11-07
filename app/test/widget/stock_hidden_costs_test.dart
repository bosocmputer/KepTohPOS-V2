import 'dart:io';

import 'package:app/app.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository whose user may not read costs, like a cashier in Supabase mode.
class _NoCostsRepository extends MockPosRepository {
  new({required super.initialState, super.sessionStaffId});

  @override
  bool get canReadCosts => false;
}

MockPosRepository _seeded(DateTime now) {
  const keys = <String>[
    'shop',
    'packages',
    'addons',
    'suppliers',
    'ingredients',
    'tables',
    'staff',
    'payments',
    'expense_types',
    'fixed_costs',
  ];
  return MockPosRepository.fromJsonStrings(
    <String, String>{
      for (final k in keys) k: File('assets/mock/$k.json').readAsStringSync(),
    },
    now: now,
    sessionStaffId: 'st3',
  );
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 12);

  Future<void> pumpStock(WidgetTester tester, MockPosRepository repo) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      KepTohApp(repository: repo, now: fixedNow, initialLocation: '/stock'),
    );
    await tester.pumpAndSettle();
  }

  Text textByKey(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key)));

  testWidgets('without cost access, stock amounts show a dash', (tester) async {
    // Arrange
    final seeded = _seeded(fixedNow);
    final repo = _NoCostsRepository(
      initialState: seeded.state,
      sessionStaffId: 'st3',
    );
    expect(
      repo.state.expenses.where((e) => e.date == '2026-11-04'),
      isNotEmpty,
    );
    await pumpStock(tester, repo);

    // Act & Assert: expenses keep their rows but not their amounts
    await tester.tap(find.text('ค่าใช้จ่าย'));
    await tester.pumpAndSettle();
    expect(textByKey(tester, 'expense-day-total').data, '–');
    expect(find.textContaining('รวม –'), findsOneWidget);
    expect(find.textContaining('฿'), findsNothing);

    // Act & Assert: balance value is hidden in both views
    await tester.tap(find.text('คงเหลือ'));
    await tester.pumpAndSettle();
    expect(textByKey(tester, 'balance-total-value').data, '–');
    await tester.tap(find.byKey(const ValueKey('stock-view-grid-btn')));
    await tester.pumpAndSettle();
    expect(textByKey(tester, 'balance-total-value').data, '–');
    expect(find.textContaining('มูลค่า –'), findsWidgets);
  });

  testWidgets('with cost access, the same screens show amounts', (
    tester,
  ) async {
    // Arrange
    await pumpStock(tester, _seeded(fixedNow));

    // Act
    await tester.tap(find.text('ค่าใช้จ่าย'));
    await tester.pumpAndSettle();

    // Assert
    expect(textByKey(tester, 'expense-day-total').data, isNot('–'));
    expect(textByKey(tester, 'expense-day-total').data, contains('฿'));
  });
}
