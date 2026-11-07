import 'dart:io';

import 'package:app/app.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PosRepository _buildFullRepo({
  required DateTime fixedNow,
  String sessionStaffId = 'st1',
}) {
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
  final jsonByName = <String, String>{
    for (final k in keys) k: File('assets/mock/$k.json').readAsStringSync(),
  };
  return MockPosRepository.fromJsonStrings(
    jsonByName,
    now: fixedNow,
    sessionStaffId: sessionStaffId,
  );
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 12);

  testWidgets(
    'new package form shows default prices in baht and saves satang',
    (tester) async {
      // Arrange
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixedNow = DateTime(2026, 11, 4, 18);
      final repo = _buildFullRepo(fixedNow: fixedNow);
      final countBefore = repo.state.packages.length;
      await tester.pumpWidget(
        KepTohApp(repository: repo, now: fixedNow, initialLocation: '/setup'),
      );
      await tester.pumpAndSettle();
      final pkgNav = find.byKey(const ValueKey('setup-tab-packages'));
      await tester.ensureVisible(pkgNav);
      await tester.tap(pkgNav);
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byKey(const ValueKey('setup-add-packages-btn')));
      await tester.pumpAndSettle();
      final inputs = tester.widgetList<TextField>(find.byType(TextField));
      final shown = inputs.map((f) => f.controller?.text).toList();
      await tester.enterText(find.byType(TextField).at(1), 'แพ็กเกจทดสอบ');
      final save = find.byKey(const ValueKey('setup-modal-save-btn'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      // Assert
      expect(shown, containsAll(<String>['199', '99']));
      expect(repo.state.packages.length, countBefore + 1);
      expect(repo.state.packages.last.adultPrice, 19900);
      expect(repo.state.packages.last.childPrice, 9900);
    },
  );

  testWidgets(
    'SetupPage renders 4 grouped nav sections, dedicated theme tab, and CRUD',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _buildFullRepo(fixedNow: fixedNow);
      await tester.pumpWidget(
        KepTohApp(repository: repo, now: fixedNow, initialLocation: '/setup'),
      );
      await tester.pumpAndSettle();

      // 4 logical groups in left navigation
      expect(find.text('ร้านและต้นทุน'), findsOneWidget);
      expect(find.text('เมนูและพื้นที่ขาย'), findsOneWidget);
      expect(find.text('สต็อกและคู่ค้า'), findsOneWidget);
      expect(find.text('การเงินและระบบ'), findsOneWidget);

      // Theme section is NOT pinned on the shop tab
      expect(find.byKey(const ValueKey('setup-theme-section')), findsNothing);

      // Switch to dedicated 'theme' tab
      final themeNav = find.byKey(const ValueKey('setup-tab-theme'));
      await tester.ensureVisible(themeNav);
      await tester.tap(themeNav);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setup-theme-section')), findsOneWidget);

      // Select Emerald brand palette and verify persistence to ShopConfig
      final emeraldBtn = find.byKey(const ValueKey('palette-emerald'));
      await tester.ensureVisible(emeraldBtn);
      await tester.tap(emeraldBtn);
      await tester.pumpAndSettle();
      expect(repo.state.shop.themePalette, 'emerald');

      // Switch to 'packages' tab and open Add modal
      final pkgNav = find.byKey(const ValueKey('setup-tab-packages'));
      await tester.ensureVisible(pkgNav);
      await tester.tap(pkgNav);
      await tester.pumpAndSettle();

      final addBtn = find.byKey(const ValueKey('setup-add-packages-btn'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('เพิ่มแพ็กเกจบุฟเฟต์'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('setup-modal-save-btn')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SetupPage demo tab requires confirmation before clearing daily data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _buildFullRepo(fixedNow: fixedNow);
      expect(repo.state.sales, isNotEmpty);

      await tester.pumpWidget(
        KepTohApp(repository: repo, now: fixedNow, initialLocation: '/setup'),
      );
      await tester.pumpAndSettle();

      final demoNav = find.byKey(const ValueKey('setup-tab-demo'));
      await tester.ensureVisible(demoNav);
      await tester.tap(demoNav);
      await tester.pumpAndSettle();

      final clearBtn = find.byKey(const ValueKey('setup-clear-daily-btn'));
      await tester.ensureVisible(clearBtn);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Confirm modal must appear before mutating state
      expect(find.text('เริ่มข้อมูลรายวันใหม่ (0 บิล)?'), findsOneWidget);
      expect(repo.state.sales, isNotEmpty);

      await tester.tap(find.text('เริ่มรายวันใหม่'));
      await tester.pumpAndSettle();

      expect(repo.state.sales, isEmpty);
    },
  );

  test(
    'Production validation rejects duplicate table names and negative prices',
    () {
      final repo = _buildFullRepo(fixedNow: fixedNow);
      final s = repo.state;

      // Duplicate table name check (case-insensitive)
      final dupTable = upsertTableInState(
        s,
        const DiningTable(id: 't_new', name: 'a1', zone: 'ในร้าน', seats: 4),
      );
      expect(dupTable.ok, isFalse);
      expect(dupTable.message, contains('ชื่อโต๊ะนี้มีอยู่ในระบบแล้ว'));

      // Negative price check on PackageItem & AddonItem
      final negPkg = upsertPackageInState(
        s,
        const PackageItem(
          id: 'p_neg',
          name: 'แพ็กเกจผิด',
          adultPrice: -1000,
          childPrice: 9900,
        ),
      );
      expect(negPkg.ok, isFalse);

      final negAddon = upsertAddonInState(
        s,
        AddonItem(
          id: 'a_neg',
          name: 'น้ำอัดลม',
          category: 'เครื่องดื่ม',
          price: 2000,
          cost: -500,
          stock: 10,
        ),
      );
      expect(negAddon.ok, isFalse);
    },
  );
}
