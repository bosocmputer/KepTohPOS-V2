import 'dart:io';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

MockPosRepository _createGoldenRepo() {
  final fixedNow = DateTime(2026, 11, 4, 12);
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
  return MockPosRepository.fromJsonStrings(jsonByName, now: fixedNow);
}

void main() {
  group('Login Screen Golden Test', () {
    testWidgets('LoginPage at 1366x1024 matches golden', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _createGoldenRepo();
      final authCubit = AuthCubit(repo)..setPin('12');
      addTearDown(authCubit.close);

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(brightness: Brightness.light),
            home: const LoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('login_1366x1024.png'),
      );
    });
  });
}
