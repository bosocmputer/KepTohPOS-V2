import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Red "ยกเลิก" banner with who voided the bill and why.
class ReceiptVoidStamp extends StatelessWidget {
  const new({required this.bill, super.key});

  final BillRecord bill;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
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
}

/// PromptPay QR block printed on unpaid slips.
class ReceiptQrBox extends StatelessWidget {
  const new({required this.shop, required this.bill, super.key});

  final ShopConfig shop;
  final BillRecord bill;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
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
            '${baht(bill.total, bill.total % 100 != 0 ? 2 : 0)}',
            style: tt.labelSmall?.copyWith(color: t.muted),
          ),
          const SizedBox(height: AppDimensions.space2),
          RepaintBoundary(
            child: Container(
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
          ),
        ],
      ),
    );
  }
}
