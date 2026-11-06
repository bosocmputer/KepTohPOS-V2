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
}
