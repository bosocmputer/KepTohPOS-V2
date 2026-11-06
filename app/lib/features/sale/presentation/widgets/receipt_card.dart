import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Formatted thermal-style receipt card (`const Receipt` in `index.html`).
class ReceiptCard extends StatelessWidget {
  const new({
    required this.shop,
    required this.bill,
    this.isCopy = false,
    super.key,
  });
  final ShopConfig shop;
  final BillRecord bill;
  final bool isCopy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final effVatMode = bill.vatMode ?? shop.vatMode;
    final effVatRate = bill.vatRate ?? shop.vatRate;
    final docTitle = bill.isSlipPreview
        ? 'ใบแจ้งยอดค่าอาหาร (ยังไม่ได้ชำระเงิน)'
        : (effVatMode != 'none'
              ? 'ใบเสร็จรับเงิน/ใบกำกับภาษีอย่างย่อ'
              : 'ใบเสร็จรับเงิน');
    final showQr =
        !bill.voided &&
        (bill.methodType == 'qr' ||
            (bill.isSlipPreview && shop.promptpay.trim().isNotEmpty));
    final div = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space2),
      child: Divider(color: t.line, height: 1),
    );
    final limTxt = formatTimeLimitLabel(bill.timeLimitMin);
    final d = dkey(DateTime.parse(bill.at).toLocal());
    final h = bill.heads;
    final hTxt =
        'ลูกค้า: ผู้ใหญ่ ${h.a}${h.c > 0 ? " · เด็ก ${h.c}" : ""}'
        '${h.f > 0 ? " · ฟรี ${h.f}" : ""}';
    String fmtAmt(double v) => baht(v, v % 1 != 0 ? 2 : 0);

    return Container(
      key: const ValueKey('receipt-card'),
      padding: const EdgeInsets.all(AppDimensions.space4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bill.voided) ...[
            _voidStamp(t, tt),
            const SizedBox(height: AppDimensions.space3),
          ],
          const Center(child: BrandLogo(size: AppDimensions.space10)),
          const SizedBox(height: AppDimensions.space1_5),
          Text(
            shop.name,
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final info in <String>[
            if (shop.branch.isNotEmpty) shop.branch,
            if (shop.address.isNotEmpty) shop.address,
            if (shop.phone.isNotEmpty) 'โทร ${shop.phone}',
            if (shop.taxId.isNotEmpty) 'เลขผู้เสียภาษี ${shop.taxId}',
          ])
            Text(
              info,
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(color: t.muted),
            ),
          div,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  key: const ValueKey('receipt-doc-title'),
                  docTitle,
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(
                    color: bill.isSlipPreview ? t.primaryInk : t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isCopy && !bill.isSlipPreview) ...[
                const SizedBox(width: AppDimensions.space1_5),
                const Pill(key: ValueKey('receipt-copy-badge'), label: 'สำเนา'),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.space1_5),
          _row(t, tt, 'เลขที่ ${bill.no}', 'โต๊ะ ${bill.tableName}'),
          _row(
            t,
            tt,
            '${thDate(d)} · ${thTime(bill.at)} น.',
            'แคชเชียร์: ${bill.staffName}',
          ),
          Text(hTxt, style: tt.labelSmall?.copyWith(color: t.muted)),
          if (shop.useTimer)
            Text(
              key: const ValueKey('receipt-eat-until'),
              bill.eatUntil != null && bill.timeLimitMin > 0
                  ? 'ทานได้ถึงเวลา ${thTime(bill.eatUntil!)} น. (จำกัด $limTxt)'
                  : 'ไม่จำกัดเวลา',
              style: tt.labelSmall?.copyWith(
                color: bill.timeLimitMin > 0 ? t.primaryInk : t.muted,
                fontWeight: bill.timeLimitMin > 0
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          div,
          for (final l in bill.lines)
            _row(t, tt, '${l.name} × ${l.qty}', baht(l.qty * l.price), true),
          div,
          _row(t, tt, 'ยอดรวม', baht(bill.subtotal)),
          if (bill.service > 0)
            _row(
              t,
              tt,
              'ค่าบริการ (${fmtQ(shop.servicePct)}%)',
              baht(bill.service, 2),
            ),
          if (effVatMode != 'none' && bill.vat > 0) ...[
            _row(t, tt, 'มูลค่าก่อนภาษี', baht(bill.total - bill.vat, 2)),
            _row(
              t,
              tt,
              'VAT ${fmtQ(effVatRate)}% '
              '(${effVatMode == "included" ? "รวมในราคา" : "แยกนอก"})',
              baht(bill.vat, 2),
            ),
          ],
          if (bill.rounding != 0) _row(t, tt, 'ปัดเศษ', baht(bill.rounding, 2)),
          const SizedBox(height: AppDimensions.space1_5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'รวมทั้งสิ้น',
                style: tt.titleMedium?.copyWith(
                  color: t.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                key: const ValueKey('receipt-total-amount'),
                fmtAmt(bill.total),
                style: tt.titleLarge?.copyWith(
                  color: bill.voided ? t.muted : t.primary,
                  fontWeight: FontWeight.w700,
                  decoration: bill.voided ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space2),
          _row(
            t,
            tt,
            bill.isSlipPreview
                ? 'สถานะ: รอชำระเงิน (${bill.methodName})'
                : 'ชำระโดย ${bill.methodName}',
            bill.methodType == 'cash' && !bill.isSlipPreview
                ? 'รับเงิน ${baht(bill.received, 2)}'
                : '',
          ),
          if ((bill.bankAccountInfo ?? '').isNotEmpty)
            _row(t, tt, 'บัญชีรับโอน', bill.bankAccountInfo!, true),
          if (bill.methodType == 'cash' && !bill.isSlipPreview)
            _row(t, tt, 'เงินทอน', fmtAmt(bill.change), true),
          if (showQr) ...[
            const SizedBox(height: AppDimensions.space2_5),
            _qrSection(t, tt),
          ],
          if (shop.receiptFooter.isNotEmpty) ...[
            div,
            Text(
              shop.receiptFooter,
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(color: t.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    AppTokens t,
    TextTheme tt,
    String l,
    String r, [
    bool b = false,
  ]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceHalf),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(l, style: tt.bodySmall?.copyWith(color: t.ink)),
        ),
        if (r.isNotEmpty)
          Text(
            r,
            style: tt.bodySmall?.copyWith(
              color: t.ink,
              fontWeight: b ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
      ],
    ),
  );

  Widget _voidStamp(AppTokens t, TextTheme tt) {
    final r = (bill.voidReason ?? '').trim();
    final msg =
        'ยกเลิกโดย ${bill.voidBy ?? "-"} · ${r.isEmpty ? "ไม่ระบุ" : r}';
    return Container(
      key: const ValueKey('receipt-void-stamp'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space3,
        vertical: AppDimensions.space2,
      ),
      decoration: BoxDecoration(
        color: t.dangerSoft,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: t.danger),
      ),
      child: Row(
        children: [
          const Pill(tone: PillTone.red, label: 'ยกเลิก'),
          const SizedBox(width: AppDimensions.space2),
          Expanded(
            child: Text(
              msg,
              style: tt.bodySmall?.copyWith(
                color: t.dangerInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrSection(AppTokens t, TextTheme tt) => Container(
    key: const ValueKey('receipt-qr-box'),
    padding: const EdgeInsets.all(AppDimensions.space2_5),
    decoration: BoxDecoration(
      color: t.surface2,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      border: Border.all(color: t.line),
    ),
    child: Column(
      children: [
        Text(
          'สแกน QR พร้อมเพย์เพื่อชำระเงิน',
          style: tt.bodySmall?.copyWith(
            color: t.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'พร้อมเพย์ ${shop.promptpay} · ยอดโอน '
          '${baht(bill.total, bill.total % 1 != 0 ? 2 : 0)}',
          style: tt.labelSmall?.copyWith(color: t.muted),
        ),
        const SizedBox(height: AppDimensions.space2),
        Container(
          padding: const EdgeInsets.all(AppDimensions.space1_5),
          decoration: BoxDecoration(
            color: AppRawTokens.paper,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(color: t.primary),
          ),
          child: QrImageView(
            data: promptPayPayload(shop.promptpay, bill.total),
            size: 120,
            backgroundColor: AppRawTokens.paper,
          ),
        ),
      ],
    ),
  );
}
