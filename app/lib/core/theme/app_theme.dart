import 'dart:async';

import 'package:app/core/theme/tokens.dart';
import 'package:app/domain/models.dart';
import 'package:app/domain/pos_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Builds a [ThemeData] from [AppTokens] for the active brightness and brand
/// palette using bundled offline fonts (`Anuphan` and `IBM Plex Sans Thai`).
abstract final class AppTheme {
  static ThemeData build({
    required Brightness brightness,
    AppBrandPalette palette = AppBrandPalette.orange,
  }) {
    final tokens = AppTokens.resolve(brightness: brightness, palette: palette);
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppDimensions.fontBody,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
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

/// Immutable state for active [AppThemeMode] and [AppBrandPalette].
class ThemeState extends Equatable {
  const new({
    this.mode = AppThemeMode.light,
    this.palette = AppBrandPalette.orange,
  });

  final AppThemeMode mode;
  final AppBrandPalette palette;

  ThemeState copyWith({AppThemeMode? mode, AppBrandPalette? palette}) =>
      ThemeState(mode: mode ?? this.mode, palette: palette ?? this.palette);

  @override
  List<Object?> get props => [mode, palette];
}

/// Cubit controlling mode (`light` | `dark` | `system`) and brand palette,
/// persisting changes into [ShopConfig] when a [PosRepository] is attached.
class ThemeCubit extends Cubit<ThemeState> {
  new({ThemeState? initialState, PosRepository? repository})
    : _repository = repository,
      super(
        initialState ??
            (repository != null
                ? ThemeState(
                    mode: AppThemeMode.fromId(repository.state.shop.themeMode),
                    palette: AppBrandPalette.fromId(
                      repository.state.shop.themePalette,
                    ),
                  )
                : const ThemeState()),
      ) {
    _sub = _repository?.stream.listen((s) {
      if (isClosed) return;
      final nextMode = AppThemeMode.fromId(s.shop.themeMode);
      final nextPalette = AppBrandPalette.fromId(s.shop.themePalette);
      if (nextMode != state.mode || nextPalette != state.palette) {
        emit(state.copyWith(mode: nextMode, palette: nextPalette));
      }
    });
  }

  final PosRepository? _repository;
  StreamSubscription<PosState>? _sub;

  void setMode(AppThemeMode mode) {
    emit(state.copyWith(mode: mode));
    unawaited(_repository?.saveThemePreference(mode: mode.id));
  }

  void setPalette(AppBrandPalette palette) {
    emit(state.copyWith(palette: palette));
    unawaited(_repository?.saveThemePreference(palette: palette.id));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
