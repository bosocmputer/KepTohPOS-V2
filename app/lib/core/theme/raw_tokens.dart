import 'package:flutter/material.dart';

/// Layer 1 raw palette (`--figma-*` and theme-invariant tokens).
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
  static const double productCardImgH = 112;

  static const double headerH = 88;
  static const double sidebarW = 232;
  static const double railW = 96;
  static const double drawerW = 365;
  static const double orderPanelW = 396;
  static const double mobileBp = 760;
}
