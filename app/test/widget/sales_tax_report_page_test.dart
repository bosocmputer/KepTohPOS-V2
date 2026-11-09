import 'dart:io';

import 'package:app/app.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MockPosRepository _repo(DateTime now, String staffId) {
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
    sessionStaffId: staffId,
  )..update((s) {
    final pkg = s.packages.first;
    makeBill(
      s,
      id: 'tx1',
      at: now.toUtc().toIso8601String(),
      tableId: 't1',
      staffId: s.staff.first.id,
      packageId: pkg.id,
      order: calcOrder(s.shop, pkg, 2, 0, 0, <AddonLineInput>[]),
      method: s.payments.first,
      received: 50000,
    );
  });
}

void main() {
  final now = DateTime(2026, 11, 9, 12);

  testWidgets('owner opens the tax report and sees rows and daily summary', (
    tester,
  ) async {
    // Arrange
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _repo(now, 'st1');
    final bill = repo.state.sales.firstWhere((b) => b.id == 'tx1');
    await tester.pumpWidget(
      KepTohApp(repository: repo, now: now, initialLocation: '/reports'),
    );
    await tester.pumpAndSettle();

    // Act
    await tester.tap(find.text('ภาษีขาย'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text(bill.no), findsWidgets);
    expect(find.byKey(const ValueKey('sales-tax-totals')), findsOneWidget);
    expect(find.text('สรุปรายวันรายเครื่อง'), findsOneWidget);
    expect(find.text('ส่งออก CSV'), findsOneWidget);
    final table = find.byType(PosDataTable<SalesTaxRow>);
    expect(
      find.descendant(of: table, matching: find.text('รวม')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: table, matching: find.text('หมายเหตุ')),
      findsOneWidget,
    );
    final buyerCell = find
        .ancestor(of: find.text('–').first, matching: find.byType(Column))
        .first;
    expect(tester.widget<Column>(buyerCell).children, hasLength(1));
    expect(
      find.descendant(
        of: find.byType(Toolbar),
        matching: find.byKey(const ValueKey('sales-tax-export')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cashier never gets the tax report entry', (tester) async {
    // Arrange
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _repo(now, 'st3');

    // Act
    await tester.pumpWidget(
      KepTohApp(repository: repo, now: now, initialLocation: '/reports'),
    );
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('ภาษีขาย'), findsNothing);
  });

  testWidgets('non-VAT shop hides the entry for the owner', (tester) async {
    // Arrange
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _repo(now, 'st1')
      ..update((s) => s.shop = s.shop.copyWith(vatRegistered: false));

    // Act
    await tester.pumpWidget(
      KepTohApp(repository: repo, now: now, initialLocation: '/reports'),
    );
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('ภาษีขาย'), findsNothing);
  });
}
