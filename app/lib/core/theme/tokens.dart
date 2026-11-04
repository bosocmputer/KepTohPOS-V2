import 'package:flutter/material.dart';

/// Brand themes supported by KepToh POS (`data-brand="figma|team"`).
enum AppBrand {
  figma('Figma'),
  team('ทีม');

  new(this.label);
  final String label;
}

/// Theme modes supported by KepToh POS (`light | dark | system`).
enum AppThemeMode {
  light('สว่าง', ThemeMode.light),
  dark('มืด', ThemeMode.dark),
  system('ตามเครื่อง', ThemeMode.system);

  new(this.label, this.themeMode);
  final String label;
  final ThemeMode themeMode;
}

/// Layer 1 raw palette (`--figma-*`, `--team-*`, and theme-invariant tokens).
abstract final class AppRawTokens {
  // Figma · Makaryo POS kit
  static const Color figmaOrange50 = Color(0xFFFFF4ED);
  static const Color figmaOrange100 = Color(0xFFFFE6D4);
  static const Color figmaOrange500 = Color(0xFFFE4E10);
  static const Color figmaOrange600 = Color(0xFFEF3408);
  static const Color figmaOrangeInk = Color(0xFFB42A08);
  static const Color figmaNeutral50 = Color(0xFFF8F8F8);
  static const Color figmaNeutral100 = Color(0xFFE7E7E7);
  static const Color figmaNeutral300 = Color(0xFFB0B0B0);
  static const Color figmaNeutral400 = Color(0xFF888888);
  static const Color figmaNeutral500 = Color(0xFF6D6D6D);
  static const Color figmaNeutral600 = Color(0xFF5D5D5D);
  static const Color figmaNeutral900 = Color(0xFF3D3D3D);
  static const Color figmaNeutral950 = Color(0xFF000000);
  static const Color figmaGray100 = Color(0xFFF2F4F7);
  static const Color figmaGray200 = Color(0xFFE4E7EC);
  static const Color figmaGreen50 = Color(0xFFF0FDF4);
  static const Color figmaGreen100 = Color(0xFFDCFCE7);
  static const Color figmaGreen600 = Color(0xFF16A34A);
  static const Color figmaGreen700 = Color(0xFF15803D);
  static const Color figmaRed50 = Color(0xFFFEF2F2);
  static const Color figmaRed600 = Color(0xFFDC2626);
  static const Color figmaRed700 = Color(0xFFB91C1C);
  static const Color figmaDark = Color(0xFF141B34);

  // Team palette
  static const Color teamOrange = Color(0xFFFF7A00);
  static const Color teamOrange600 = Color(0xFFE56D00);
  static const Color teamOrangeSoft = Color(0xFFFFF1E4);
  static const Color teamOrangeSoft2 = Color(0xFFFFE2C7);
  static const Color teamOrangeInk = Color(0xFFB35300);
  static const Color teamCharcoal = Color(0xFF20242C);
  static const Color teamGray = Color(0xFFF4F4F5);
  static const Color teamSurface2 = Color(0xFFFAFAFB);
  static const Color teamNavy = Color(0xFF172033);
  static const Color teamGreen = Color(0xFF16A36A);
  static const Color teamGreenSoft = Color(0xFFE6F6EE);
  static const Color teamGreenInk = Color(0xFF0F7A52);
  static const Color teamRed = Color(0xFFE5484D);
  static const Color teamRedSoft = Color(0xFFFDECEC);
  static const Color teamRedInk = Color(0xFFB42328);
  static const Color teamMuted = Color(0xFF5B6475);
  static const Color teamLine = Color(0xFFE2E3E8);
  static const Color teamSideInkLight = Color(0xFFC7CAD2);
  static const Color teamSideDark = Color(0xFF0C0E12);
  static const Color teamSideInkDark = Color(0xFFAEB3BE);

  // Dark mode base tokens
  static const Color darkBg = Color(0xFF121419);
  static const Color darkSurface = Color(0xFF1C1F26);
  static const Color darkSurface2 = Color(0xFF22262E);
  static const Color darkInk = Color(0xFFECEEF3);
  static const Color darkMuted = Color(0xFF9BA2AF);
  static const Color darkLine = Color(0xFF30343D);
  static const Color darkChip = Color(0xFF2A2F3A);

  // Theme-invariant tokens (receipt paper, QR, PromptPay)
  static const Color white = Color(0xFFFFFFFF);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color paperInk = Color(0xFF172033);
  static const Color paperRule = Color(0xFFA3A9B5);
  static const Color paperMuted = Color(0xFF5B6475);
  static const Color paperDanger = Color(0xFFB91C1C);
  static const Color qrBg = Color(0xFFFFFFFF);
  static const Color qrInk = Color(0xFF172033);
  static const Color promptPayBlue = Color(0xFF113566);
  static const Color scrim = Color.fromRGBO(14, 16, 21, 0.55);
  static const Color teamSideHover = Color.fromRGBO(255, 255, 255, 0.06);
}

/// Layer 2 non-color layout, typography, spacing, and radius tokens.
abstract final class AppDimensions {
  static const String fontDisplay = 'Anuphan';
  static const String fontBody = 'IBM Plex Sans Thai';

  static const double fsXs = 12;
  static const double fsSm = 14;
  static const double fsBase = 15;
  static const double fsMd = 16;

  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double r = radiusMd;

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;

  static const double tap = 44;
  static const double sidebarW = 232;
  static const double railW = 96;
  static const double drawerW = 365;
}

/// Layer 2 semantic color tokens (`--primary`, `--surface`, `--ink`, etc.).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const new({
    required this.brand,
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

  factory figmaLight() => const AppTokens(
    brand: AppBrand.figma,
    brightness: Brightness.light,
    primary: AppRawTokens.figmaOrange500,
    primaryHover: AppRawTokens.figmaOrange600,
    primarySoft: AppRawTokens.figmaOrange50,
    primarySoft2: AppRawTokens.figmaOrange100,
    primaryInk: AppRawTokens.figmaOrangeInk,
    onPrimary: AppRawTokens.white,
    bg: AppRawTokens.figmaNeutral50,
    surface: AppRawTokens.white,
    surface2: AppRawTokens.figmaGray100,
    ink: AppRawTokens.figmaNeutral950,
    muted: AppRawTokens.figmaNeutral500,
    line: AppRawTokens.figmaNeutral100,
    success: AppRawTokens.figmaGreen600,
    successSoft: AppRawTokens.figmaGreen100,
    successInk: AppRawTokens.figmaGreen700,
    danger: AppRawTokens.figmaRed600,
    dangerSoft: AppRawTokens.figmaRed50,
    dangerInk: AppRawTokens.figmaRed700,
    dark: AppRawTokens.figmaDark,
    onDark: AppRawTokens.white,
    side: AppRawTokens.white,
    sideInk: AppRawTokens.figmaNeutral500,
    sideInkStrong: AppRawTokens.figmaNeutral950,
    sideHover: AppRawTokens.figmaNeutral50,
    sideLine: AppRawTokens.figmaNeutral100,
    shadows: _lightShadows,
  );

  factory teamLight() => const AppTokens(
    brand: AppBrand.team,
    brightness: Brightness.light,
    primary: AppRawTokens.teamOrange,
    primaryHover: AppRawTokens.teamOrange600,
    primarySoft: AppRawTokens.teamOrangeSoft,
    primarySoft2: AppRawTokens.teamOrangeSoft2,
    primaryInk: AppRawTokens.teamOrangeInk,
    onPrimary: AppRawTokens.teamCharcoal,
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
    side: AppRawTokens.teamCharcoal,
    sideInk: AppRawTokens.teamSideInkLight,
    sideInkStrong: AppRawTokens.white,
    sideHover: AppRawTokens.teamSideHover,
    sideLine: Colors.transparent,
    shadows: _lightShadows,
  );

  factory figmaDark() => AppTokens._darkFrom(AppTokens.figmaLight());

  factory teamDark() => AppTokens._darkFrom(
    AppTokens.teamLight(),
    sideOverride: AppRawTokens.teamSideDark,
    sideInkOverride: AppRawTokens.teamSideInkDark,
    sideInkStrongOverride: AppRawTokens.white,
    sideHoverOverride: AppRawTokens.teamSideHover,
    sideLineOverride: Colors.transparent,
  );

  factory resolve({required AppBrand brand, required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    return switch ((brand, isDark)) {
      (AppBrand.figma, false) => AppTokens.figmaLight(),
      (AppBrand.figma, true) => AppTokens.figmaDark(),
      (AppBrand.team, false) => AppTokens.teamLight(),
      (AppBrand.team, true) => AppTokens.teamDark(),
    };
  }

  factory _darkFrom(
    AppTokens base, {
    Color? sideOverride,
    Color? sideInkOverride,
    Color? sideInkStrongOverride,
    Color? sideHoverOverride,
    Color? sideLineOverride,
  }) {
    const surface = AppRawTokens.darkSurface;
    return AppTokens(
      brand: base.brand,
      brightness: Brightness.dark,
      primary: base.primary,
      primaryHover: base.primaryHover,
      primarySoft: Color.lerp(surface, base.primary, 0.20)!,
      primarySoft2: Color.lerp(surface, base.primary, 0.32)!,
      primaryInk: Color.lerp(AppRawTokens.white, base.primary, 0.60)!,
      onPrimary: base.onPrimary,
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
      side: sideOverride ?? surface,
      sideInk: sideInkOverride ?? AppRawTokens.darkMuted,
      sideInkStrong: sideInkStrongOverride ?? AppRawTokens.darkInk,
      sideHover: sideHoverOverride ?? AppRawTokens.darkSurface2,
      sideLine: sideLineOverride ?? AppRawTokens.darkLine,
      shadows: _darkShadows,
    );
  }

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

  final AppBrand brand;
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

  @override
  AppTokens copyWith({
    AppBrand? brand,
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
    brand: brand ?? this.brand,
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
      Theme.of(this).extension<AppTokens>() ?? AppTokens.figmaLight();
}
