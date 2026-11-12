import 'dart:convert';
import 'dart:ui' as ui;

import 'package:app/core/printer/shop_logo_picker_stub.dart'
    if (dart.library.js_interop) 'package:app/core/printer/shop_logo_picker_web.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/brand_logo.dart';
import 'package:app/core/widgets/btn.dart';
import 'package:app/domain/shop_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Decodes a `data:image/...;base64,<payload>` URL (or raw base64 string) into
/// raw image bytes, returning `null` if [dataUrl] is empty or malformed.
Uint8List? decodeLogoDataUrl(String? dataUrl) {
  final raw = (dataUrl ?? '').trim();
  if (raw.isEmpty) return null;
  final comma = raw.indexOf(',');
  final b64 = comma >= 0 ? raw.substring(comma + 1).trim() : raw;
  if (b64.isEmpty) return null;
  try {
    final bytes = base64Decode(b64);
    return bytes.isNotEmpty ? bytes : null;
  } on Object {
    return null;
  }
}

/// Decodes the custom shop logo [logoDataUrl] (or falls back to the bundled
/// `'assets/logo.jpg'` brand icon when [fallbackToBrandAsset] is `true`) into a
/// [ui.Image] ready for canvas rasterization on thermal receipts.
Future<ui.Image?> loadReceiptLogoImage({
  String? logoDataUrl,
  bool fallbackToBrandAsset = true,
}) async {
  final customBytes = decodeLogoDataUrl(logoDataUrl);
  if (customBytes != null) {
    final decoded = await _decodeUiImage(customBytes);
    if (decoded != null) return decoded;
  }
  if (!fallbackToBrandAsset) return null;
  try {
    final data = await rootBundle.load('assets/logo.jpg');
    return await _decodeUiImage(data.buffer.asUint8List());
  } on Object {
    return null;
  }
}

Future<ui.Image?> _decodeUiImage(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 220);
    final frame = await codec.getNextFrame();
    return frame.image;
  } on Object {
    return null;
  }
}

/// Opens a file chooser on Web (or returns a sample 1x1 PNG in tests) and
/// returns a normalized `data:image/png;base64,...` string.
Future<String?> pickShopLogoDataUrl() => pickShopLogoDataUrlImpl();

/// Resolves the logo [ui.Image] for [shop] when [printLogo] is `true`.
Future<ui.Image?> resolveShopLogo(
  ShopConfig shop, {
  bool printLogo = true,
  String? logoDataUrl,
}) => printLogo
    ? loadReceiptLogoImage(
        logoDataUrl: (logoDataUrl ?? '').isNotEmpty
            ? logoDataUrl
            : shop.logoDataUrl,
      )
    : Future<ui.Image?>.value();

/// Reusable logo upload/reset control used in both `SetupShopPanel`
/// (`ตั้งค่า > ร้านและใบเสร็จ`) and `PrinterHubBody` (`หน้าต่างเครื่องพิมพ์`).
class ShopLogoPickerField extends StatelessWidget {
  const new({
    required this.logoDataUrl,
    required this.onChanged,
    super.key,
    this.compact = false,
    this.printLogo,
    this.onPrintLogoChanged,
  });

  final String logoDataUrl;
  final ValueChanged<String> onChanged;
  final bool compact;
  final bool? printLogo;
  final ValueChanged<bool>? onPrintLogoChanged;

  Future<void> _pick() async {
    final picked = await pickShopLogoDataUrl();
    if (picked != null && picked.isNotEmpty) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final hasCustom = decodeLogoDataUrl(logoDataUrl) != null;

    return Container(
      key: const ValueKey('shop-logo-picker-field'),
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.space3,
        vertical: compact ? AppDimensions.space2_5 : AppDimensions.space3,
      ),
      decoration: BoxDecoration(
        color: compact ? t.surface : t.surface2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceHalf),
            decoration: BoxDecoration(
              color: AppRawTokens.paper,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: t.line),
            ),
            child: BrandLogo(
              logoDataUrl: logoDataUrl,
              size: compact ? 40 : 48,
              radius: AppDimensions.radiusXs,
            ),
          ),
          const SizedBox(width: AppDimensions.space2_5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'โลโก้บนหัวใบเสร็จ',
                  style: tt.bodyMedium?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hasCustom ? 'โลโก้ร้านของคุณ' : 'โลโก้มาตรฐาน KepToh',
                  style: tt.labelSmall?.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          if (hasCustom) ...[
            Btn(
              key: const ValueKey('reset-shop-logo-btn'),
              size: BtnSize.sm,
              kind: BtnKind.ghost,
              label: 'ค่าเริ่มต้น',
              onPressed: () => onChanged(''),
            ),
            const SizedBox(width: AppDimensions.space1_5),
          ],
          Btn(
            key: const ValueKey('pick-shop-logo-btn'),
            size: BtnSize.sm,
            label: hasCustom ? 'เปลี่ยนรูป' : 'อัปโหลดโลโก้',
            onPressed: _pick,
          ),
          if (printLogo != null && onPrintLogoChanged != null) ...[
            const SizedBox(width: AppDimensions.space2_5),
            Switch.adaptive(
              key: const ValueKey('printer-print-logo-switch'),
              value: printLogo!,
              activeTrackColor: t.primary,
              onChanged: onPrintLogoChanged,
            ),
          ],
        ],
      ),
    );
  }
}
