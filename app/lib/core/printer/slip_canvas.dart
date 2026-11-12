import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/core/printer/esc_pos_raster.dart';
import 'package:app/core/printer/printer_models.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/painting.dart';
import 'package:qr_flutter/qr_flutter.dart';

const Color _kBlack = Color(0xFF000000);
const double _kPad = 16;

/// Offscreen 203-DPI thermal receipt canvas (`576px` for 80mm, `384px` for
/// 58mm) that renders shop logos, Thai text, banners, line items, and QR codes.
class SlipCanvas {
  new(this.pw)
    : w = pw.dots.toDouble(),
      s = pw == PaperWidth.mm80 ? 1.0 : 0.72 {
    final bg = ui.Paint()..color = const Color(0xFFFFFFFF);
    canvas = ui.Canvas(recorder)..drawRect(ui.Rect.fromLTWH(0, 0, w, 8000), bg);
  }

  final PaperWidth pw;
  final double w;
  final double s;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  late final ui.Canvas canvas;
  double y = 16;

  void logo(ui.Image? img) {
    if (img == null) return;
    final sx = (200 * s) / img.width;
    final sy = (104 * s) / img.height;
    final sc = sx < sy ? sx : sy;
    final dw = (img.width * sc).roundToDouble();
    final dh = (img.height * sc).roundToDouble();
    final src = ui.Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final dst = ui.Rect.fromLTWH(((w - dw) / 2).roundToDouble(), y, dw, dh);
    canvas.drawImageRect(
      img,
      src,
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    y += dh + (8 * s).roundToDouble();
  }

  void div() {
    y += (6 * s).roundToDouble();
    final p = ui.Paint()..color = _kBlack;
    for (var x = _kPad; x < w - _kPad - 4; x += 12) {
      canvas.drawRect(ui.Rect.fromLTWH(x, y, 7, 2), p);
    }
    y += (8 * s).roundToDouble();
  }

  /// Flags [f]: `1` = bold, `2` = center, `3` = bold + center.
  void txt(String v, [double sz = 19, int f = 0]) {
    if (v.trim().isEmpty) return;
    final tp = _tp(v, w - 32, sz * s, f)..paint(canvas, ui.Offset(_kPad, y));
    y += tp.height + 4 * s;
  }

  void header(ShopConfig shop, [ui.Image? lg, List<String> tax = const []]) {
    logo(lg);
    txt(shop.name.isNotEmpty ? shop.name : 'เก็บโต๊ะ POS', 29, 3);
    final tel = shop.phone.isNotEmpty ? 'โทร ${shop.phone}' : '';
    for (final l in <String>[shop.branch, shop.address, tel, ...tax]) {
      txt(l, 19, 2);
    }
  }

  void meta((ShopConfig, HeadsCount, String?, int, String, String) m) {
    final (shop, h, u, min, pfx, late) = m;
    final c = h.c > 0 ? ' · เด็ก ${h.c}' : '';
    final f = h.f > 0 ? ' · ฟรี ${h.f}' : '';
    txt('$pfx: ผู้ใหญ่ ${h.a}$c$f');
    if (!shop.useTimer) return;
    final lim = formatTimeLimitLabel(min);
    final eat = u != null && min > 0
        ? 'ทานได้ถึงเวลา ${thTime(u)} น. (จำกัด $lim)'
        : 'ไม่จำกัดเวลา';
    late.isNotEmpty ? row(eat, late, 19, 2) : txt(eat, 19, min > 0 ? 1 : 0);
  }

  void banner(String title, [String? sub]) {
    final iw = w - 32;
    final t1 = _tp(title, iw - 20, 23 * s, 3);
    final t2 = (sub ?? '').isNotEmpty ? _tp(sub!, iw - 20, 19 * s, 3) : null;
    final bh = t1.height + (t2 != null ? t2.height + 6 : 0) + 18 * s;
    final stroke = ui.Paint()
      ..color = _kBlack
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(ui.Rect.fromLTWH(_kPad, y, iw, bh), stroke);
    t1.paint(canvas, ui.Offset(_kPad + 10, y + 9 * s));
    t2?.paint(canvas, ui.Offset(_kPad + 10, y + 9 * s + t1.height + 4));
    y += bh + 10 * s;
  }

  /// Bit flags [f]: `1` = bold left, `2` = bold right, `8` = lineThrough.
  void row(String l, String r, [double sz = 20, int f = 0]) {
    final iw = w - 32;
    final fs = sz * s;
    final rf = ((f & 3) != 0 ? 5 : 4) | (f & 8);
    final rTp = r.isNotEmpty ? _tp(r, iw * 0.48, fs, rf) : null;
    final lMax = rTp != null ? (iw - rTp.width - 12).clamp(60.0, iw) : iw;
    final lTp = _tp(l, lMax, fs, (f & 1) | (f & 8))
      ..paint(canvas, ui.Offset(_kPad, y));
    rTp?.paint(canvas, ui.Offset(w - _kPad - rTp.width, y));
    final rh = rTp?.height ?? 0;
    y += (rh > lTp.height ? rh : lTp.height) + 5 * s;
  }

  void items(List<OrderLineItem> ls) {
    for (final l in ls) {
      row('${l.name} × ${l.qty}', baht(l.qty * l.price), 21, 2);
    }
  }

  void qr(String payload, [double sz = 210]) {
    final q = (sz * s).roundToDouble();
    y += (6 * s).roundToDouble();
    canvas
      ..save()
      ..translate(((w - q) / 2).roundToDouble(), y);
    QrPainter(
      data: payload,
      version: QrVersions.auto,
      gapless: true,
    ).paint(canvas, ui.Size(q, q));
    canvas.restore();
    y += q + 10 * s;
  }

  TextPainter _tp(String t, double w, double sz, int f) {
    final a0 = (f & 2) != 0 ? TextAlign.center : TextAlign.left;
    final a = (f & 4) != 0 ? TextAlign.right : a0;
    final st = TextStyle(
      fontFamily: 'IBM Plex Sans Thai',
      fontSize: sz,
      fontWeight: (f & 1) != 0 ? FontWeight.w700 : FontWeight.w500,
      color: _kBlack,
      height: 1.26,
      decoration: (f & 8) != 0 ? TextDecoration.lineThrough : null,
    );
    return TextPainter(
      text: TextSpan(text: t, style: st),
      textAlign: a,
      textDirection: ui.TextDirection.ltr,
    )..layout(minWidth: a == TextAlign.center ? w : 0, maxWidth: w);
  }

  Future<Uint8List> out({bool png = false}) async {
    final h = (y + 20).ceil().clamp(32, 8000);
    final img = await recorder.endRecording().toImage(pw.dots, h);
    final fmt = png ? ui.ImageByteFormat.png : ui.ImageByteFormat.rawRgba;
    final bd = (await img.toByteData(format: fmt))?.buffer.asUint8List();
    img.dispose();
    final raw = bd ?? Uint8List(0);
    return png ? raw : encodeRgbaToEscPos(raw, pw.dots, h);
  }
}
