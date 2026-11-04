import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

/// Formatted thermal-style receipt card (`const Receipt` in
/// `prototype/index.html`) featuring `BrandLogo` (`assets/logo.jpg`).
class ReceiptCard extends StatelessWidget {
  const new({required this.shop, required this.bill, super.key});

  final ShopConfig shop;
  final BillRecord bill;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;

    return Container(
      key: const ValueKey('receipt-card'),
      padding: const EdgeInsets.all(AppDimensions.space5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: BrandLogo(
              size: AppDimensions.space12,
              radius: AppDimensions.radiusMd,
            ),
          ),
          const SizedBox(height: AppDimensions.space2_5),
          Text(
            shop.name,
            textAlign: TextAlign.center,
            style: tt.titleLarge?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (shop.branch.isNotEmpty)
            Text(
              shop.branch,
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(color: t.muted),
            ),
          if (shop.address.isNotEmpty)
            Text(
              shop.address,
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(color: t.muted),
            ),
          if (shop.phone.isNotEmpty)
            Text(
              'โทร ${shop.phone}',
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(color: t.muted),
            ),
          if (shop.taxId.isNotEmpty)
            Text(
              'เลขผู้เสียภาษี ${shop.taxId}',
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(color: t.muted),
            ),
          const SizedBox(height: AppDimensions.space3),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space3),
          Text(
            shop.vatMode != 'none'
                ? 'ใบเสร็จรับเงิน/ใบกำกับภาษีอย่างย่อ'
                : 'ใบเสร็จรับเงิน',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.space2),
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
          const SizedBox(height: AppDimensions.space3),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space2_5),
          for (final l in bill.lines)
            _ReceiptRow(
              '${l.name} × ${l.qty}',
              baht(l.qty * l.price),
              boldValue: true,
            ),
          const SizedBox(height: AppDimensions.space2_5),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space2_5),
          _ReceiptRow('ยอดรวม', baht(bill.subtotal)),
          if (bill.service > 0)
            _ReceiptRow(
              'ค่าบริการ (${fmtQ(shop.servicePct)}%)',
              baht(bill.service, 2),
            ),
          if (shop.vatMode != 'none' && bill.vat > 0)
            _ReceiptRow(
              'VAT 7% (${shop.vatMode == "included" ? "รวมในราคา" : "แยก"})',
              baht(bill.vat, 2),
            ),
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
                  color: t.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space2),
          _ReceiptRow(
            'ชำระโดย ${bill.methodName}',
            bill.methodType == 'cash'
                ? 'รับเงิน ${baht(bill.received, 2)}'
                : '',
          ),
          if (bill.methodType == 'cash')
            _ReceiptRow(
              'เงินทอน',
              baht(bill.change, bill.change % 1 != 0 ? 2 : 0),
              boldValue: true,
            ),
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

/// Modal dialog displayed after settling a bill (`const ReceiptModal` in
/// `prototype/index.html`).
class ReceiptModal extends StatelessWidget {
  const new({
    required this.shop,
    required this.bill,
    required this.onDone,
    super.key,
    this.fresh = true,
    this.onPrint,
  });

  final ShopConfig shop;
  final BillRecord bill;
  final VoidCallback onDone;
  final bool fresh;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final changeTxt = baht(bill.change, bill.change % 1 != 0 ? 2 : 0);

    return Material(
      key: const ValueKey('receipt-modal'),
      color: t.scrim,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.space4),
          child: Modal(
            title: fresh ? 'รับเงินเรียบร้อย' : 'ใบเสร็จ ${bill.no}',
            onClose: onDone,
            footer: [
              Btn(
                key: const ValueKey('receipt-print-btn'),
                icon: 'printer',
                label: 'พิมพ์ใบเสร็จ',
                onPressed: onPrint ?? () {},
              ),
              Btn(
                key: const ValueKey('receipt-done-btn'),
                kind: BtnKind.primary,
                icon: 'check',
                label: fresh ? 'เสร็จสิ้น' : 'ปิด',
                onPressed: onDone,
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (fresh) ...[
                  ResultState(
                    title: 'รับเงินเรียบร้อย',
                    text: bill.methodType == 'cash' && bill.change > 0
                        ? 'เงินทอน $changeTxt'
                        : 'ชำระผ่าน ${bill.methodName}',
                  ),
                  const SizedBox(height: AppDimensions.space3),
                ],
                ReceiptCard(shop: shop, bill: bill),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
