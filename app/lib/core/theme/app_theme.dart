import 'package:app/core/theme/tokens.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

/// Builds a [ThemeData] from [AppTokens] for the active brand and brightness.
abstract final class AppTheme {
  static ThemeData build({
    required AppBrand brand,
    required Brightness brightness,
  }) {
    final tokens = AppTokens.resolve(brand: brand, brightness: brightness);
    final baseTheme = ThemeData(useMaterial3: true, brightness: brightness);

    final bodyFont = GoogleFonts.ibmPlexSansThai(color: tokens.ink);
    final displayStyle = GoogleFonts.anuphan(color: tokens.ink);
    final textTheme = baseTheme.textTheme.copyWith(
      displayLarge: displayStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: displayStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: displayStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: displayStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: displayStyle.copyWith(
        fontSize: AppDimensions.fsMd,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: bodyFont.copyWith(
        fontSize: AppDimensions.fsMd,
        color: tokens.ink,
      ),
      bodyMedium: bodyFont.copyWith(
        fontSize: AppDimensions.fsBase,
        color: tokens.ink,
      ),
      bodySmall: bodyFont.copyWith(
        fontSize: AppDimensions.fsSm,
        color: tokens.muted,
      ),
      labelSmall: bodyFont.copyWith(
        fontSize: AppDimensions.fsXs,
        color: tokens.muted,
      ),
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.primary,
      onPrimary: tokens.onPrimary,
      secondary: tokens.primarySoft,
      onSecondary: tokens.primaryInk,
      error: tokens.danger,
      onError: AppRawTokens.white,
      surface: tokens.surface,
      onSurface: tokens.ink,
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: tokens.bg,
      colorScheme: colorScheme,
      textTheme: textTheme,
      dividerColor: tokens.line,
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }
}

/// Immutable state for active [AppBrand] and [AppThemeMode].
class ThemeState extends Equatable {
  const new({this.brand = AppBrand.figma, this.mode = AppThemeMode.light});

  final AppBrand brand;
  final AppThemeMode mode;

  ThemeState copyWith({AppBrand? brand, AppThemeMode? mode}) =>
      ThemeState(brand: brand ?? this.brand, mode: mode ?? this.mode);

  @override
  List<Object?> get props => [brand, mode];
}

/// Cubit controlling brand (`figma` | `team`) and mode (`light` | `dark`).
class ThemeCubit extends Cubit<ThemeState> {
  new({ThemeState initialState = const ThemeState()}) : super(initialState);

  void setBrand(AppBrand brand) => emit(state.copyWith(brand: brand));

  void setMode(AppThemeMode mode) => emit(state.copyWith(mode: mode));
}
