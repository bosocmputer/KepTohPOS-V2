import 'package:app/app.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTokens (theme.css figma brand parity)', () {
    test('resolves light and dark tokens accurately', () {
      final light = AppTokens.resolve(brightness: Brightness.light);
      final dark = AppTokens.resolve(brightness: Brightness.dark);

      expect(light.primary, AppRawTokens.figmaOrange500);
      expect(light.bg, AppRawTokens.figmaNeutral50);
      expect(light.surface, AppRawTokens.white);
      expect(light.side, AppRawTokens.white);
      expect(light.ink, AppRawTokens.figmaNeutral950);

      expect(dark.primary, AppRawTokens.figmaOrange500);
      expect(dark.bg, AppRawTokens.darkBg);
      expect(dark.surface, AppRawTokens.darkSurface);
      expect(dark.side, AppRawTokens.darkSurface);
      expect(dark.ink, AppRawTokens.darkInk);
    });
  });

  group('KepTohApp F0 shell and theme mode switching', () {
    testWidgets('renders empty bootstrap screen and switches mode', (
      tester,
    ) async {
      await tester.pumpWidget(const KepTohApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('shell-menu-btn')));
      await tester.pumpAndSettle();

      expect(find.text('KepToh POS'), findsOneWidget);
      expect(find.text('ธีมและการแสดงผล'), findsOneWidget);
      expect(find.text('ธีมสี'), findsNothing);

      final context = tester.element(find.text('KepToh POS'));
      final cubit = context.read<ThemeCubit>();
      expect(cubit.state.mode, AppThemeMode.light);

      await tester.tap(find.byKey(const ValueKey('mode-dark')));
      await tester.pumpAndSettle();
      expect(cubit.state.mode, AppThemeMode.dark);

      await tester.tap(find.byKey(const ValueKey('mode-system')));
      await tester.pumpAndSettle();
      expect(cubit.state.mode, AppThemeMode.system);
    });
  });
}
