import 'package:app/core/theme/tokens.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Builds a [ThemeData] from [AppTokens] for the active brightness using
/// bundled offline fonts (`Anuphan` and `IBM Plex Sans Thai`).
abstract final class AppTheme {
  static ThemeData build({required Brightness brightness}) {
    final tokens = AppTokens.resolve(brightness: brightness);
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppDimensions.fontBody,
    );

    final bodyFont = TextStyle(
      fontFamily: AppDimensions.fontBody,
      color: tokens.ink,
    );
    final displayStyle = TextStyle(
      fontFamily: AppDimensions.fontDisplay,
      color: tokens.ink,
    );
    final textTheme = baseTheme.textTheme.copyWith(
      displayLarge: displayStyle.copyWith(
        fontSize: AppDimensions.fsMoney,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: displayStyle.copyWith(
        fontSize: AppDimensions.fsH1,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: displayStyle.copyWith(
        fontSize: AppDimensions.fsH1,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: displayStyle.copyWith(
        fontSize: AppDimensions.fsH1,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: displayStyle.copyWith(
        fontSize: AppDimensions.fsH2,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: displayStyle.copyWith(
        fontSize: AppDimensions.fsH2,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: displayStyle.copyWith(
        fontSize: AppDimensions.fsMd,
        fontWeight: FontWeight.w700,
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

/// Immutable state for active [AppThemeMode].
class ThemeState extends Equatable {
  const new({this.mode = AppThemeMode.light});

  final AppThemeMode mode;

  ThemeState copyWith({AppThemeMode? mode}) =>
      ThemeState(mode: mode ?? this.mode);

  @override
  List<Object?> get props => [mode];
}

/// Cubit controlling mode (`light` | `dark` | `system`).
class ThemeCubit extends Cubit<ThemeState> {
  new({ThemeState initialState = const ThemeState()}) : super(initialState);

  void setMode(AppThemeMode mode) => emit(state.copyWith(mode: mode));
}
