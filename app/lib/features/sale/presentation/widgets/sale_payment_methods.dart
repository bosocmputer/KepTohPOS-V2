import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:app/features/sale/presentation/widgets/sale_payment_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Cash received + quick bank buttons + change + `NumPad` (`payment_cash.png`).
class CashPaymentSection extends StatelessWidget {
  const new({
    required this.state,
    required this.staff,
    super.key,
    this.compact = false,
  });

  final SaleState state;
  final StaffMember staff;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SaleBloc>();
    final total = state.payOrder.total;
    final recv = state.cashReceivedAmount;
    final quicks = SalePaymentPanel.quickCashAmounts(total);
    final gap = compact ? AppDimensions.space2 : AppDimensions.space3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppDimensions.space2,
          runSpacing: AppDimensions.space2,
          children: [
            for (final v in quicks)
              Btn(
                key: ValueKey('quick-cash-${v == total ? "exact" : v ~/ 100}'),
                size: BtnSize.sm,
                kind: recv == v ? BtnKind.primary : BtnKind.normal,
                label: v == total ? 'พอดี' : baht(v),
                onPressed: () =>
                    bloc.add(SaleCashReceivedChanged(bahtInputText(v))),
              ),
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            _cashBox(context, isChange: false),
            const SizedBox(width: AppDimensions.space2),
            _cashBox(context, isChange: true),
          ],
        ),
        SizedBox(height: gap),
        NumPad(
          value: state.cashReceived,
          maxLen: 7,
          filledKeys: true,
          showClear: true,
          maxWidth: double.infinity,
          keyHeight: compact
              ? AppDimensions.numPadKeyCompactH
              : AppDimensions.numPadKeyH,
          rowGap: compact ? AppDimensions.space1_5 : AppDimensions.space2,
          onChanged: (v) => bloc.add(SaleCashReceivedChanged(v)),
          onEnter: state.canConfirmPayment
              ? (_) => bloc.add(SalePaymentSubmitted(staff: staff))
              : null,
        ),
      ],
    );
  }

  Widget _cashBox(BuildContext context, {required bool isChange}) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final recv = state.cashReceivedAmount;
    final short = recv > 0 && recv < state.payOrder.total;
    final fg = short ? t.danger : t.success;
    final amt = short ? state.cashShortage : state.cashChange;
    return Expanded(
      child: Container(
        key: isChange ? null : const ValueKey('cash-received-box'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space3,
          vertical: AppDimensions.space2,
        ),
        decoration: BoxDecoration(
          color: isChange ? (short ? t.dangerSoft : t.successSoft) : t.surface2,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: isChange ? fg : t.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isChange ? (short ? 'ยังขาดอีก' : 'เงินทอน') : 'รับเงินมา',
              style: tt.labelSmall?.copyWith(
                color: isChange ? fg : t.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceHalf),
            Text(
              key: isChange ? const ValueKey('cash-change-amount') : null,
              isChange
                  ? baht(amt, amt % 100 != 0 ? 2 : 0)
                  : (state.cashReceived.isEmpty ? '฿0' : baht(recv)),
              style: tt.titleLarge?.copyWith(
                color: isChange ? fg : t.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PromptPay EMVCo QR code card (`const PromptPayQR` in `prototype/index.html`
/// & `design/figma/payment_qris.png`).
class PromptPayQR extends StatelessWidget {
  const new({required this.promptpayId, required this.amount, super.key});
  final String promptpayId;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final payload = promptPayPayload(promptpayId, amount);

    return Container(
      key: const ValueKey('promptpay-qr-card'),
      padding: const EdgeInsets.all(AppDimensions.space4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          Text(
            'สแกน QR พร้อมเพย์',
            style: tt.titleMedium?.copyWith(color: t.ink),
          ),
          const SizedBox(height: AppDimensions.space1),
          Text(
            'พร้อมเพย์ $promptpayId',
            style: tt.labelSmall?.copyWith(color: t.muted),
          ),
          const SizedBox(height: AppDimensions.space3),
          Container(
            padding: const EdgeInsets.all(AppDimensions.space2_5),
            decoration: BoxDecoration(
              color: AppRawTokens.paper,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(
                color: t.primary,
                width: AppDimensions.borderBold,
              ),
            ),
            child: QrImageView(
              data: payload,
              size: 164,
              backgroundColor: AppRawTokens.paper,
            ),
          ),
          const SizedBox(height: AppDimensions.space2_5),
          Text(
            baht(amount, amount % 100 != 0 ? 2 : 0),
            style: tt.headlineMedium?.copyWith(
              color: t.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the QR when the shop has no PromptPay number yet.
class PromptPayMissing extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('promptpay-missing'),
      padding: const EdgeInsets.all(AppDimensions.space4),
      decoration: BoxDecoration(
        color: t.dangerSoft,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: t.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ร้านยังไม่ได้ตั้งเบอร์พร้อมเพย์',
            style: tt.titleMedium?.copyWith(color: t.danger),
          ),
          const SizedBox(height: AppDimensions.space1),
          Text(
            'สร้าง QR ไม่ได้ ให้เจ้าของร้านใส่เบอร์ที่ '
            'ตั้งค่า › ร้านและใบเสร็จ หรือเลือกรับเงินวิธีอื่น',
            style: tt.bodySmall?.copyWith(color: t.ink),
          ),
        ],
      ),
    );
  }
}

/// Transfer / card summary card for non-cash/non-QR payment methods.
class TransferStatusSection extends StatelessWidget {
  const new({required this.methodName, this.bankAccount, super.key});

  final String methodName;
  final BankAccountItem? bankAccount;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final acctLabel = bankAccount?.fullLabel ?? '';
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space4),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          Container(
            width: AppDimensions.space12,
            height: AppDimensions.space12,
            decoration: BoxDecoration(
              color: t.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Center(child: AppIcon('bank', color: t.primaryInk)),
          ),
          const SizedBox(height: AppDimensions.space2),
          Text(
            'รับชำระผ่าน $methodName',
            style: tt.titleMedium?.copyWith(color: t.ink),
          ),
          if (acctLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.space1),
              child: Text(
                'บัญชีรับโอน: $acctLabel',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(
                  color: t.primaryInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: AppDimensions.space1),
          Text(
            'ตรวจสอบสลิปหรือยอดเงินเข้าบัญชีก่อนกดยืนยัน',
            textAlign: TextAlign.center,
            style: tt.labelSmall?.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}
