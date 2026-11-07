import 'dart:convert';
import 'dart:io';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

PosRepository _buildRepo(DateTime fixedNow) {
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
  final prefix = Directory('assets/mock').existsSync()
      ? 'assets/mock'
      : 'app/assets/mock';
  final jsonByName = <String, String>{
    for (final k in keys) k: File('$prefix/$k.json').readAsStringSync(),
  };
  return MockPosRepository.fromJsonStrings(jsonByName, now: fixedNow);
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 12);

  group('PosState JSON Serialization & Snapshot Round-Trip', () {
    test('toJson -> fromJson preserves master catalogs & transactions', () {
      final repo = _buildRepo(fixedNow);
      final original = repo.state;

      final exported = repo.exportStateJson();
      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      final restored = PosState.fromJson(decoded);

      expect(restored.shop.name, original.shop.name);
      expect(restored.packages.length, original.packages.length);
      expect(restored.addons.length, original.addons.length);
      expect(restored.ingredients.length, original.ingredients.length);
      expect(restored.suppliers.length, original.suppliers.length);
      expect(restored.tables.length, original.tables.length);
      expect(restored.staff.length, original.staff.length);
      expect(restored.payments.length, original.payments.length);
      expect(restored.fixedCosts.length, original.fixedCosts.length);
      expect(restored.expenseTypes.length, original.expenseTypes.length);
      expect(restored.sales.length, original.sales.length);
      expect(restored.purchases.length, original.purchases.length);
      expect(restored.expenses.length, original.expenses.length);
      expect(restored.shifts.length, original.shifts.length);
      expect(restored.openTables.length, original.openTables.length);
      expect(restored.counts.length, original.counts.length);
      expect(restored.seq.length, original.seq.length);
    });

    test('importStateJson restores modified state and emits update', () {
      final repo = _buildRepo(fixedNow);
      final snapshot = repo.exportStateJson();

      repo.update((s) => s.shop = s.shop.copyWith(name: 'Changed Name'));
      expect(repo.state.shop.name, 'Changed Name');

      repo.importStateJson(snapshot);
      expect(repo.state.shop.name, isNot('Changed Name'));
    });
  });

  group('SetupCubit CRUD & Relational Guards', () {
    test('create, update, inline toggle, and search filter packages', () {
      final repo = _buildRepo(fixedNow);
      final cubit = SetupCubit(repo);
      addTearDown(cubit.close);

      final initialCount = cubit.state.posState.packages.length;
      const newPkg = PackageItem(
        id: 'pkg_test_99',
        name: 'ชุดพรีเมียมวากิว',
        adultPrice: 49900,
        childPrice: 24900,
        timeLimit: 120,
      );

      final createRes = cubit.upsertPackage(newPkg);
      expect(createRes.ok, isTrue);
      expect(cubit.state.posState.packages.length, initialCount + 1);

      cubit.togglePackageActive(newPkg, active: false);
      final toggled = cubit.state.posState.packages.firstWhere(
        (p) => p.id == 'pkg_test_99',
      );
      expect(toggled.active, isFalse);

      cubit.setSearchQuery('วากิว');
      expect(cubit.state.filteredPackages.length, 1);
      expect(cubit.state.filteredPackages.first.id, 'pkg_test_99');

      cubit.setSearchQuery('');
      final delRes = cubit.deleteItem(section: 'packages', id: 'pkg_test_99');
      expect(delRes.ok, isTrue);
      expect(cubit.state.posState.packages.length, initialCount);
    });

    test('relational delete guard blocks deleting package used in sales', () {
      final repo = _buildRepo(fixedNow);
      final cubit = SetupCubit(repo);
      addTearDown(cubit.close);

      final usedPkgId = cubit.state.posState.sales.first.packageId;
      final canDel = cubit.checkCanDelete(section: 'packages', id: usedPkgId);
      expect(canDel, isFalse);
      expect(cubit.state.guardModalMessage, isNotEmpty);

      final res = cubit.deleteItem(section: 'packages', id: usedPkgId);
      expect(res.ok, isFalse);
      expect(res.isGuardBlock, isTrue);
    });

    test('relational delete guard blocks deleting currently open table', () {
      final repo = _buildRepo(fixedNow);
      final cubit = SetupCubit(repo);
      addTearDown(cubit.close);

      final openTableId = cubit.state.posState.openTables.keys.first;
      final res = cubit.deleteItem(section: 'tables', id: openTableId);
      expect(res.ok, isFalse);
      expect(res.isGuardBlock, isTrue);
    });

    test('non-owner cannot modify staff accounts', () {
      final repo = _buildRepo(fixedNow);
      final cubit = SetupCubit(repo);
      addTearDown(cubit.close);

      const st = StaffMember(
        id: 'st_new',
        name: 'พนักงานใหม่',
        role: 'cashier',
        pin: '9999',
      );
      final denied = cubit.upsertStaff(st, actorRole: 'manager');
      expect(denied.ok, isFalse);

      final allowed = cubit.upsertStaff(st, actorRole: 'owner');
      expect(allowed.ok, isTrue);
    });
  });
}
