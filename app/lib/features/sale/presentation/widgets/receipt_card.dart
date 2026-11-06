import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Formatted thermal-style receipt card (`const Receipt` in
/// `prototype/index.html`) featuring `BrandLogo` (`assets/logo.jpg`) and
/// embedded EMVCo PromptPay QR for QR/Pre-settlement slips.
class ReceiptCard extends StatelessWidget {
  const new({required this.shop, required this.bill, super.key});

  final ShopConfig shop;
  final BillRecord bill;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final reasonTxt = (bill.voidReason ?? '').trim().isNotEmpty
        ? bill.voidReason!
        : 'ไม่ระบุ';
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
            _voidStamp(t, tt, reasonTxt),
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
          const SizedBox(height: AppDimensions.space2),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space2),
          Text(
            key: const ValueKey('receipt-doc-title'),
            docTitle,
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: bill.isSlipPreview ? t.primaryInk : t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.space1_5),
          _ReceiptRow('เลขที่ ${bill.no}', 'โต๊ะ ${bill.tableName}'),
          _ReceiptRow(
            '${thDate(bill.date)} · ${thTime(bill.at)} น.',
            'แคชเชียร์: ${bill.staffName}',
          ),
          Text(
            'ลูกค้า: ผู้ใหญ่ ${bill.heads.a}'
            '${bill.heads.c > 0 ? " · เด็ก ${bill.heads.c}" : ""}'
            '${bill.heads.f > 0 ? " · ฟรี ${bill.heads.f}" : ""}',
            style: tt.labelSmall?.copyWith(color: t.muted),
          ),
          const SizedBox(height: AppDimensions.space2),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space2),
          for (final l in bill.lines)
            _ReceiptRow(
              '${l.name} × ${l.qty}',
              baht(l.qty * l.price),
              boldValue: true,
            ),
          const SizedBox(height: AppDimensions.space2),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space2),
          _ReceiptRow('ยอดรวม', baht(bill.subtotal)),
          if (bill.service > 0)
            _ReceiptRow(
              'ค่าบริการ (${fmtQ(shop.servicePct)}%)',
              baht(bill.service, 2),
            ),
          if (effVatMode != 'none' && bill.vat > 0) ...[
            _ReceiptRow('มูลค่าก่อนภาษี', baht(bill.total - bill.vat, 2)),
            _ReceiptRow(
              'VAT ${fmtQ(effVatRate)}% '
              '(${effVatMode == "included" ? "รวมในราคา" : "แยกนอก"})',
              baht(bill.vat, 2),
            ),
          ],
          if (bill.rounding != 0) _ReceiptRow('ปัดเศษ', baht(bill.rounding, 2)),
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
                baht(bill.total, bill.total % 1 != 0 ? 2 : 0),
                style: tt.titleLarge?.copyWith(
                  color: bill.voided ? t.muted : t.primary,
                  fontWeight: FontWeight.w700,
                  decoration: bill.voided ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space2),
          _ReceiptRow(
            bill.isSlipPreview
                ? 'สถานะ: รอชำระเงิน (${bill.methodName})'
                : 'ชำระโดย ${bill.methodName}',
            bill.methodType == 'cash' && !bill.isSlipPreview
                ? 'รับเงิน ${baht(bill.received, 2)}'
                : '',
          ),
          if ((bill.bankAccountInfo ?? '').isNotEmpty)
            _ReceiptRow('บัญชีรับโอน', bill.bankAccountInfo!, boldValue: true),
          if (bill.methodType == 'cash' && !bill.isSlipPreview)
            _ReceiptRow(
              'เงินทอน',
              baht(bill.change, bill.change % 1 != 0 ? 2 : 0),
              boldValue: true,
            ),
          if (showQr) ...[
            const SizedBox(height: AppDimensions.space2_5),
            _qrSection(t, tt),
          ],
          if (shop.receiptFooter.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space3),
            Divider(color: t.line, height: 1),
            const SizedBox(height: AppDimensions.space2_5),
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

  Widget _voidStamp(AppTokens t, TextTheme tt, String reasonTxt) => Container(
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
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: t.danger,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'ยกเลิก',
            style: tt.labelSmall?.copyWith(
              color: AppRawTokens.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.space2_5),
        Expanded(
          child: Text(
            'ยกเลิกโดย ${bill.voidBy ?? "-"} · $reasonTxt',
            style: tt.bodySmall?.copyWith(
              color: t.dangerInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _qrSection(AppTokens t, TextTheme tt) {
    final payload = promptPayPayload(shop.promptpay, bill.total);
    return Container(
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
              data: payload,
              size: 120,
              backgroundColor: AppRawTokens.paper,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const new(this.left, this.right, {this.boldValue = false});

  final String left;
  final String right;
  final bool boldValue;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceHalf),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(left, style: tt.bodySmall?.copyWith(color: t.ink)),
          ),
          if (right.isNotEmpty)
            Text(
              right,
              style: tt.bodySmall?.copyWith(
                color: t.ink,
                fontWeight: boldValue ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
