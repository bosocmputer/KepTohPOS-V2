import 'package:app/app.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTokens (theme.css parity)', () {
    test('resolves 2 brands x light/dark accurately', () {
      final figmaLight = AppTokens.resolve(
        brand: AppBrand.figma,
        brightness: Brightness.light,
      );
      final figmaDark = AppTokens.resolve(
        brand: AppBrand.figma,
        brightness: Brightness.dark,
      );
      final teamLight = AppTokens.resolve(
        brand: AppBrand.team,
        brightness: Brightness.light,
      );
      final teamDark = AppTokens.resolve(
        brand: AppBrand.team,
        brightness: Brightness.dark,
      );

      expect(figmaLight.primary, AppRawTokens.figmaOrange500);
      expect(figmaLight.bg, AppRawTokens.figmaNeutral50);
      expect(figmaLight.side, AppRawTokens.white);

      expect(teamLight.primary, AppRawTokens.teamOrange);
      expect(teamLight.onPrimary, AppRawTokens.teamCharcoal);
      expect(teamLight.bg, AppRawTokens.teamGray);
      expect(teamLight.side, AppRawTokens.teamCharcoal);

      expect(figmaDark.bg, AppRawTokens.darkBg);
      expect(figmaDark.surface, AppRawTokens.darkSurface);
      expect(figmaDark.side, AppRawTokens.darkSurface);

      expect(teamDark.bg, AppRawTokens.darkBg);
      expect(teamDark.side, AppRawTokens.teamSideDark);
      expect(teamDark.sideInk, AppRawTokens.teamSideInkDark);
    });
  });

  group('KepTohApp F0 shell and theme switching', () {
    testWidgets('renders empty bootstrap screen and switches brand and mode', (
      tester,
    ) async {
      await tester.pumpWidget(const KepTohApp());
      await tester.pumpAndSettle();

      expect(find.text('KepToh POS'), findsOneWidget);
      expect(find.text('ธีมและการแสดงผล'), findsOneWidget);

      final context = tester.element(find.text('KepToh POS'));
      final cubit = context.read<ThemeCubit>();
      expect(cubit.state.brand, AppBrand.figma);
      expect(cubit.state.mode, AppThemeMode.light);

      await tester.tap(find.byKey(const ValueKey('brand-team')));
      await tester.pumpAndSettle();
      expect(cubit.state.brand, AppBrand.team);

      await tester.tap(find.byKey(const ValueKey('mode-dark')));
      await tester.pumpAndSettle();
      expect(cubit.state.mode, AppThemeMode.dark);
    });
  });
}
