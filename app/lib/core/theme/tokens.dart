import 'package:app/core/theme/raw_tokens.dart';
import 'package:flutter/material.dart';

export 'package:app/core/theme/raw_tokens.dart';

/// Layer 2 semantic color tokens (`--primary`, `--surface`, `--ink`, etc.).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const new({
    required this.brightness,
    required this.primary,
    required this.primaryHover,
    required this.primarySoft,
    required this.primarySoft2,
    required this.primaryInk,
    required this.onPrimary,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.success,
    required this.successSoft,
    required this.successInk,
    required this.danger,
    required this.dangerSoft,
    required this.dangerInk,
    required this.dark,
    required this.onDark,
    required this.side,
    required this.sideInk,
    required this.sideInkStrong,
    required this.sideHover,
    required this.sideLine,
    required this.shadows,
  });

  factory light([AppBrandPalette palette = AppBrandPalette.orange]) =>
      AppTokens(
        brightness: Brightness.light,
        primary: palette.primary,
        primaryHover: palette.primaryHover,
        primarySoft: palette.primarySoft,
        primarySoft2: palette.primarySoft2,
        primaryInk: palette.primaryInk,
        onPrimary: palette.onPrimary,
        bg: AppRawTokens.teamGray,
        surface: AppRawTokens.white,
        surface2: AppRawTokens.teamSurface2,
        ink: AppRawTokens.teamNavy,
        muted: AppRawTokens.teamMuted,
        line: AppRawTokens.teamLine,
        success: AppRawTokens.teamGreen,
        successSoft: AppRawTokens.teamGreenSoft,
        successInk: AppRawTokens.teamGreenInk,
        danger: AppRawTokens.teamRed,
        dangerSoft: AppRawTokens.teamRedSoft,
        dangerInk: AppRawTokens.teamRedInk,
        dark: AppRawTokens.teamCharcoal,
        onDark: AppRawTokens.white,
        side: AppRawTokens.white,
        sideInk: AppRawTokens.teamMuted,
        sideInkStrong: AppRawTokens.teamNavy,
        sideHover: AppRawTokens.teamGray,
        sideLine: AppRawTokens.teamLine,
        shadows: _lightShadows,
      );

  factory dark([AppBrandPalette palette = AppBrandPalette.orange]) {
    final base = AppTokens.light(palette);
    const surface = AppRawTokens.darkSurface;
    return AppTokens(
      brightness: Brightness.dark,
      primary: base.primary,
      primaryHover: base.primaryHover,
      primarySoft: Color.lerp(surface, base.primary, 0.20)!,
      primarySoft2: Color.lerp(surface, base.primary, 0.32)!,
      primaryInk: Color.lerp(AppRawTokens.white, base.primary, 0.60)!,
      onPrimary: palette.onPrimary,
      bg: AppRawTokens.darkBg,
      surface: surface,
      surface2: AppRawTokens.darkSurface2,
      ink: AppRawTokens.darkInk,
      muted: AppRawTokens.darkMuted,
      line: AppRawTokens.darkLine,
      success: base.success,
      successSoft: Color.lerp(surface, base.success, 0.18)!,
      successInk: Color.lerp(AppRawTokens.white, base.success, 0.55)!,
      danger: base.danger,
      dangerSoft: Color.lerp(surface, base.danger, 0.18)!,
      dangerInk: Color.lerp(AppRawTokens.white, base.danger, 0.55)!,
      dark: AppRawTokens.darkChip,
      onDark: AppRawTokens.darkInk,
      side: surface,
      sideInk: AppRawTokens.darkMuted,
      sideInkStrong: AppRawTokens.darkInk,
      sideHover: AppRawTokens.darkSurface2,
      sideLine: AppRawTokens.darkLine,
      shadows: _darkShadows,
    );
  }

  factory resolve({
    required Brightness brightness,
    AppBrandPalette palette = AppBrandPalette.orange,
  }) => brightness == Brightness.dark
      ? AppTokens.dark(palette)
      : AppTokens.light(palette);

  static const List<BoxShadow> _lightShadows = [
    BoxShadow(
      color: Color.fromRGBO(23, 32, 51, 0.06),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color.fromRGBO(23, 32, 51, 0.06),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  static const List<BoxShadow> _darkShadows = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.30),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  final Brightness brightness;
  final Color primary;
  final Color primaryHover;
  final Color primarySoft;
  final Color primarySoft2;
  final Color primaryInk;
  final Color onPrimary;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color muted;
  final Color line;
  final Color success;
  final Color successSoft;
  final Color successInk;
  final Color danger;
  final Color dangerSoft;
  final Color dangerInk;
  final Color dark;
  final Color onDark;
  final Color side;
  final Color sideInk;
  final Color sideInkStrong;
  final Color sideHover;
  final Color sideLine;
  final List<BoxShadow> shadows;
  Color get scrim => AppRawTokens.scrim;

  @override
  AppTokens copyWith({
    Brightness? brightness,
    Color? primary,
    Color? primaryHover,
    Color? primarySoft,
    Color? primarySoft2,
    Color? primaryInk,
    Color? onPrimary,
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? ink,
    Color? muted,
    Color? line,
    Color? success,
    Color? successSoft,
    Color? successInk,
    Color? danger,
    Color? dangerSoft,
    Color? dangerInk,
    Color? dark,
    Color? onDark,
    Color? side,
    Color? sideInk,
    Color? sideInkStrong,
    Color? sideHover,
    Color? sideLine,
    List<BoxShadow>? shadows,
  }) => AppTokens(
    brightness: brightness ?? this.brightness,
    primary: primary ?? this.primary,
    primaryHover: primaryHover ?? this.primaryHover,
    primarySoft: primarySoft ?? this.primarySoft,
    primarySoft2: primarySoft2 ?? this.primarySoft2,
    primaryInk: primaryInk ?? this.primaryInk,
    onPrimary: onPrimary ?? this.onPrimary,
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    success: success ?? this.success,
    successSoft: successSoft ?? this.successSoft,
    successInk: successInk ?? this.successInk,
    danger: danger ?? this.danger,
    dangerSoft: dangerSoft ?? this.dangerSoft,
    dangerInk: dangerInk ?? this.dangerInk,
    dark: dark ?? this.dark,
    onDark: onDark ?? this.onDark,
    side: side ?? this.side,
    sideInk: sideInk ?? this.sideInk,
    sideInkStrong: sideInkStrong ?? this.sideInkStrong,
    sideHover: sideHover ?? this.sideHover,
    sideLine: sideLine ?? this.sideLine,
    shadows: shadows ?? this.shadows,
  );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.light();
}
