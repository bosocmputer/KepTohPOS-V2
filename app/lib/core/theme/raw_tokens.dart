import 'package:flutter/material.dart';

/// Layer 1 raw palette (`--team-*` and theme-invariant tokens from
/// `prototype/theme.css`).
abstract final class AppRawTokens {
  // Team brand palette (--team-* in prototype/theme.css lines 27–31)
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
  static const Color teamDarkSide = Color(0xFF0C0E12);
  static const Color teamDarkSideInk = Color(0xFFAEB3BE);

  // Dark mode base tokens (:root[data-theme="dark"] in prototype/theme.css)
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
}

/// Layer 2 non-color layout, typography, spacing, and radius tokens.
abstract final class AppDimensions {
  static const String fontDisplay = 'Anuphan';
  static const String fontBody = 'IBM Plex Sans Thai';

  // Typography scale: H1 = 24, H2 = 18, body = 15–16, money = 28–32
  static const double fs2xs = 11;
  static const double fsXs = 12;
  static const double fsSm = 14;
  static const double fsBase = 15;
  static const double fsMd = 16;
  static const double fsLg = 18;
  static const double fsH2 = 18;
  static const double fsXl = 20;
  static const double fs2xl = 22;
  static const double fs3xl = 24;
  static const double fsH1 = 24;
  static const double fsMoney = 28;
  static const double fsMoneyLg = 32;

  static const double iconXs = 16;
  static const double iconSm = 18;
  static const double iconMd = 20;
  static const double iconLg = 22;
  static const double iconXl = 24;
  static const double icon2xl = 28;

  static const double borderThin = 1;
  static const double borderThick = 1.5;
  static const double borderBold = 2;
  static const double borderAccent = 3;

  // Radius scale: buttons & cards = 12
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;
  static const double r = radiusMd;

  // Strict 6-step spacing scale: 4 / 8 / 12 / 16 / 24 / 32
  static const double space0 = 0;
  static const double spaceHalf = 4;
  static const double space1 = 4;
  static const double space1_5 = 4;
  static const double space2 = 8;
  static const double space2_5 = 8;
  static const double space3 = 12;
  static const double space3_5 = 12;
  static const double space4 = 16;
  static const double space4_5 = 16;
  static const double space5 = 16;
  static const double space5_5 = 24;
  static const double space6 = 24;
  static const double space7 = 24;
  static const double space8 = 32;
  static const double space9 = 32;
  static const double space10 = 32;
  static const double space12 = 32;

  // Component heights & widths
  static const double tap = 44;
  static const double btnSmH = 36;
  static const double btnMdH = 44;
  static const double btnLgH = 52;
  static const double dropdownMinH = 44;
  static const double dropdownMaxListH = 320;
  static const double numPadKeyH = 56;
  static const double numPadKeyCompactH = 48;
  static const double numPadMaxW = 320;
  static const double pinDotSize = 16;
  static const double avatarSm = 36;
  static const double avatarMd = 40;
  static const double avatarLg = 48;
  static const double statusDotSm = 8;
  static const double statusDotMd = 12;
  static const double modalW = 560;
  static const double modalWideW = 1000;
  static const double modalMaxHeightFactor = 0.90;
  static const double productCardImgH = 92;
  static const double topbarSearchW = 292;

  // Responsive layout breakpoints & dimensions
  static const double mobileBp = 760;
  static const double wideBp = 1180;
  static const double compactHeightBp = 820;
  static const double headerCompactH = 64;
  static const double headerH = 72;
  static const double sidebarW = 232;
  static const double railW = 96;
  static const double drawerW = 365;
  static const double rightDrawerW = 340;
  static const double orderPanelCompactW = 360;
  static const double orderPanelW = 396;

  /// Screen content & topbar horizontal padding: `24` at `>= 1180`, `16` at
  /// `< 1180`.
  static double pagePadding(double screenWidth) =>
      screenWidth >= wideBp ? space6 : space4;

  /// Topbar height: `64` when screen height `<= 820` (`1024x768`, `1180x820`),
  /// `72` at `1366x1024` (`> 820`), `52` on mobile.
  static double topbarHeight(
    double screenWidth, [
    double screenHeight = 1024,
  ]) => screenWidth <= mobileBp
      ? btnLgH
      : (screenHeight <= compactHeightBp ? headerCompactH : headerH);

  /// Right order/payment panel width: `396` at `>= 1180`, `360` at `< 1180`.
  static double rightPanelWidth(double screenWidth) =>
      screenWidth >= wideBp ? orderPanelW : orderPanelCompactW;

  /// Product catalog grid columns: `4` at `>= 1180`, `3` at `761..1179`,
  /// `2` at `<= 760`.
  static int productGridColumns(double screenWidth) =>
      screenWidth >= wideBp ? 4 : (screenWidth <= mobileBp ? 2 : 3);
}
