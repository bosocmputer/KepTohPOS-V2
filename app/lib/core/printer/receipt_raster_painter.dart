import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/core/printer/printer_models.dart';
import 'package:app/core/printer/shop_logo_picker.dart';
import 'package:app/core/printer/slip_canvas.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/utils/thai_tax.dart';
import 'package:app/domain/domain.dart';

SlipCanvas _bill(
  (ShopConfig, BillRecord, PaperWidth, bool, String?, ui.Image?) arg,
) {
  final (s, b, w, cp, r, lg) = arg;
  final c = SlipCanvas(w);
  final vr = (b.voidReason ?? '').trim();
  final why = vr.isEmpty ? 'ไม่ระบุ' : vr;
  if (b.voided) {
    c.banner(
      '[ ยกเลิกบิล / VOID ]',
      'ยกเลิกโดย ${b.voidBy ?? "-"} · เหตุผล $why',
    );
  }
  const abb = 'ใบเสร็จรับเงิน/ใบกำกับภาษีอย่างย่อ';
  var doc = b.isTaxInvoice ? abb : 'ใบเสร็จรับเงิน';
  if (b.isFullInvoice) doc = 'ใบกำกับภาษี/ใบเสร็จรับเงิน';
  if (b.isSlipPreview) doc = 'ใบแจ้งยอดค่าอาหาร (ยังไม่ได้ชำระเงิน)';
  final copyTag = cp && !b.isSlipPreview ? ' [สำเนา]' : '';
  final d = dkey(DateTime.parse(b.at).toLocal());
  c
    ..header(s, lg, b.taxLines(s, replacesNo: r))
    ..div()
    ..txt('$doc$copyTag', 23, 3);
  if (b.isFullInvoice) {
    final tid = b.buyerTaxId ?? '';
    final br = branchLabel(b.buyerBranch ?? '00000');
    c
      ..txt('ผู้ซื้อ: ${b.buyerName ?? "-"}', 20, 1)
      ..txt(b.buyerAddress ?? '')
      ..txt(tid.isNotEmpty ? 'เลขประจำตัวผู้เสียภาษี: $tid ($br)' : '');
  }
  final svc = 'ค่าบริการ (${fmtQ(s.servicePct)}%)';
  c
    ..row('เลขที่ ${b.no}', 'โต๊ะ ${b.tableName}')
    ..row('${thDate(d)} · ${thTime(b.at)} น.', 'แคชเชียร์: ${b.staffName}', 19)
    ..meta((s, b.heads, b.eatUntil, b.timeLimitMin, 'ลูกค้า', ''))
    ..div()
    ..items(b.lines)
    ..div()
    ..row('ยอดรวม', bahtSmart(b.subtotal));
  if (b.service > 0) c.row(svc, baht(b.service, 2));
  final vm = b.vatMode ?? s.vatMode;
  final vRate = b.vatRate ?? s.vatRate;
  if (vm != 'none' && b.vat > 0) {
    final mode = vm == 'included' ? 'รวมในราคา' : 'แยกนอก';
    c
      ..row('มูลค่าก่อนภาษี', baht(b.total - b.vat, 2))
      ..row('VAT ${fmtQ(vRate)}% ($mode)', baht(b.vat, 2));
  }
  if (b.rounding != 0) c.row('ปัดเศษ', baht(b.rounding, 2));
  final wait = 'สถานะ: รอชำระเงิน (${b.methodName})';
  final pL = b.isSlipPreview ? wait : 'ชำระโดย ${b.methodName}';
  final isCash = b.methodType == 'cash' && !b.isSlipPreview;
  final info = b.bankAccountInfo ?? '';
  c
    ..row('รวมทั้งสิ้น', bahtSmart(b.total), 27, b.voided ? 11 : 3)
    ..row(pL, isCash ? 'รับเงิน ${baht(b.received, 2)}' : '', 19);
  if (info.isNotEmpty) c.row('บัญชีรับโอน', info, 19, 2);
  if (isCash) c.row('เงินทอน', bahtSmart(b.change), 20, 2);
  final pp = s.promptpay.trim();
  if (!b.voided && pp.isNotEmpty && (b.methodType == 'qr' || b.isSlipPreview)) {
    c
      ..txt('สแกน QR พร้อมเพย์เพื่อชำระเงิน', 20, 3)
      ..txt('พร้อมเพย์ $pp · ยอดโอน ${bahtSmart(b.total)}', 18, 2)
      ..qr(promptPayPayload(pp, b.total));
  }
  if (s.receiptFooter.isNotEmpty) c.div();
  return c..txt(s.receiptFooter, 19, 2);
}

Future<Uint8List> renderBillEscPos({
  required ShopConfig shop,
  required BillRecord bill,
  required PaperWidth paperWidth,
  bool isCopy = false,
  String? replacesNo,
  bool printLogo = true,
  String? logoDataUrl,
}) => resolveShopLogo(
  shop,
  printLogo: printLogo,
  logoDataUrl: logoDataUrl,
).then((lg) => _bill((shop, bill, paperWidth, isCopy, replacesNo, lg)).out());

Future<Uint8List> renderReceiptPngBytes({
  required ShopConfig shop,
  required BillRecord bill,
  required PaperWidth paperWidth,
  bool isCopy = false,
  String? replacesNo,
  bool printLogo = true,
  String? logoDataUrl,
}) =>
    resolveShopLogo(shop, printLogo: printLogo, logoDataUrl: logoDataUrl).then(
      (lg) =>
          _bill((shop, bill, paperWidth, isCopy, replacesNo, lg))
              .out(png: true),
    );

Future<Uint8List> renderTableSummaryEscPos({
  required ShopConfig shop,
  required TableSummarySlip summary,
  required PaperWidth paperWidth,
  bool printLogo = true,
  String? logoDataUrl,
}) => resolveShopLogo(shop, printLogo: printLogo, logoDataUrl: logoDataUrl)
    .then((lg) {
      final s = summary;
      final vs = s.voidedCount > 0 ? ' · ยกเลิก ${s.voidedCount}' : '';
      final late = s.timer.late ? s.timer.text : '';
      final m = (
        shop,
        s.heads,
        s.eatUntil,
        s.timeLimitMin,
        'ลูกค้าสุทธิ',
        late,
      );
      final c = SlipCanvas(paperWidth)
        ..header(shop, lg)
        ..div()
        ..txt('ใบสรุปยอดโต๊ะ (ไม่ใช่ใบกำกับภาษี)', 23, 3)
        ..row('โต๊ะ ${s.tableName}', 'เปิดโต๊ะ ${thTime(s.openedAt)} น.')
        ..meta(m)
        ..div()
        ..txt('รายการบิลย่อย (${s.bills.length} บิล$vs)', 19, 1);
      for (final b in s.bills) {
        final tag = b.voided ? ' [ยกเลิก]' : '';
        final lbl = '#${b.no} (${thTime(b.at)} น.) · ${b.methodName}$tag';
        c.row(lbl, bahtSmart(b.total), 19, b.voided ? 10 : 2);
      }
      final netL = 'รวมสุทธิทั้งโต๊ะ (${s.activeBillCount} บิล)';
      return (c
            ..div()
            ..txt('รายการอาหารและเครื่องดื่มรวม', 19, 1)
            ..items(s.mergedLines)
            ..div()
            ..row(netL, bahtSmart(s.total), 25, 3))
          .out();
    });

Future<Uint8List> renderTestPrintEscPos({
  required ShopConfig shop,
  required PaperWidth paperWidth,
  required String connectionLabel,
  bool printLogo = true,
  String? logoDataUrl,
}) => resolveShopLogo(shop, printLogo: printLogo, logoDataUrl: logoDataUrl)
    .then((lg) {
      final now = DateTime.now();
      final dt =
          '${thDate(dkey(now))} ${thTime(now.toUtc().toIso8601String())} น.';
      final rawPp = shop.promptpay.trim();
      final pp = rawPp.isNotEmpty ? rawPp : '0812345678';
      final sName = shop.name.isNotEmpty ? shop.name : 'KepToh POS Demo';
      const th1 =
          'ทดสอบภาษาไทย: กขคง จฉชซ ญฎฏฐ ฒณดต ถทธน บปผฝ พฟภม ยรลว ศษสห ฬอฮ';
      const th2 =
          'วรรณยุกต์ไม่ลอย: น้ำจิ้มสุกี้ หมูกระทะ กุ้งแม่น้ำเผา ฿1,289.50';
      return (SlipCanvas(paperWidth)
            ..logo(lg)
            ..banner('เก็บโต๊ะ POS — ทดสอบเครื่องพิมพ์', sName)
            ..row('ช่องทาง', connectionLabel, 20, 2)
            ..row('ขนาดกระดาษ', paperWidth.label, 19, 2)
            ..row('เวลาทดสอบ', dt, 19, 2)
            ..div()
            ..txt(th1, 20)
            ..txt(th2, 21, 1)
            ..div()
            ..qr(promptPayPayload(pp, 8900), 185)
            ..txt('พร้อมพิมพ์ใบเสร็จหน้าร้าน KepToh POS', 20, 3))
          .out();
    });
