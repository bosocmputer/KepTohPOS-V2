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

const _kSpecs = <(String, Size, EdgeInsets)>[
  ('1024x768', Size(1024, 768), EdgeInsets.only(top: 24)),
  ('1180x820', Size(1180, 820), EdgeInsets.only(top: 24, bottom: 20)),
  ('1366x1024', Size(1366, 1024), EdgeInsets.zero),
];

void main() {
  group('Login Screen Golden Test', () {
    for (final (name, size, pad) in _kSpecs) {
      testWidgets('LoginPage at $name matches golden', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = _createGoldenRepo();
        final authCubit = AuthCubit(repo, now: DateTime(2026, 11, 4, 12))
          ..setPin('12');
        addTearDown(authCubit.close);

        await tester.pumpWidget(
          BlocProvider<AuthCubit>.value(
            value: authCubit,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(brightness: Brightness.light),
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                return LayoutBuilder(
                  builder: (context, constraints) => MediaQuery(
                    data: mq.copyWith(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      padding: pad,
                      viewPadding: pad,
                    ),
                    child: child!,
                  ),
                );
              },
              home: const LoginPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final el in find.byType(Image).evaluate()) {
            final img = el.widget as Image;
            await precacheImage(img.image, el);
          }
        });
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('login_$name.png'),
        );
      });
    }
  });
}
