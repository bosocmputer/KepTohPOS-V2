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

  static const double fs2xs = 11;
  static const double fsXs = 12;
  static const double fsSm = 14;
  static const double fsBase = 15;
  static const double fsMd = 16;
  static const double fsLg = 18;
  static const double fsXl = 20;
  static const double fs2xl = 22;
  static const double fs3xl = 24;

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

  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;
  static const double r = radiusMd;

  static const double space0 = 0;
  static const double spaceHalf = 2;
  static const double space1 = 4;
  static const double space1_5 = 6;
  static const double space2 = 8;
  static const double space2_5 = 10;
  static const double space3 = 12;
  static const double space3_5 = 14;
  static const double space4 = 16;
  static const double space4_5 = 18;
  static const double space5 = 20;
  static const double space5_5 = 22;
  static const double space6 = 24;
  static const double space7 = 28;
  static const double space8 = 32;
  static const double space9 = 36;
  static const double space10 = 40;
  static const double space12 = 48;

  static const double tap = 44;
  static const double btnSmH = 36;
  static const double btnMdH = 44;
  static const double btnLgH = 56;
  static const double dropdownMinH = 56;
  static const double dropdownMaxListH = 320;
  static const double numPadKeyH = 60;
  static const double numPadMaxW = 320;
  static const double pinDotSize = 16;
  static const double avatarSm = 36;
  static const double avatarMd = 40;
  static const double statusDotSm = 8;
  static const double statusDotMd = 12;
  static const double modalW = 560;
  static const double modalWideW = 1000;
  static const double productCardImgH = 92;
  static const double topbarSearchW = 292;

  static const double headerH = 88;
  static const double sidebarW = 232;
  static const double railW = 96;
  static const double drawerW = 365;
  static const double orderPanelW = 396;
  static const double mobileBp = 760;
}
