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
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
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
                key: ValueKey('quick-cash-${v == total ? "exact" : v.toInt()}'),
                size: BtnSize.sm,
                kind: recv == v ? BtnKind.primary : BtnKind.normal,
                label: v == total ? 'พอดี' : baht(v),
                onPressed: () => bloc.add(
                  SaleCashReceivedChanged(
                    v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: Container(
                key: const ValueKey('cash-received-box'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space3,
                  vertical: AppDimensions.space2,
                ),
                decoration: BoxDecoration(
                  color: t.surface2,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: t.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รับเงินมา',
                      style: tt.labelSmall?.copyWith(color: t.muted),
                    ),
                    const SizedBox(height: AppDimensions.spaceHalf),
                    Text(
                      state.cashReceived.isEmpty ? '฿0' : baht(recv),
                      style: tt.titleLarge?.copyWith(
                        color: t.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.space2),
            Expanded(
              child: Builder(
                builder: (_) {
                  final short = recv > 0 && recv < total;
                  final fg = short ? t.danger : t.success;
                  final amt = short ? state.cashShortage : state.cashChange;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space3,
                      vertical: AppDimensions.space2,
                    ),
                    decoration: BoxDecoration(
                      color: short ? t.dangerSoft : t.successSoft,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                      border: Border.all(color: fg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          short ? 'ยังขาดอีก' : 'เงินทอน',
                          style: tt.labelSmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceHalf),
                        Text(
                          key: const ValueKey('cash-change-amount'),
                          baht(amt, amt % 1 != 0 ? 2 : 0),
                          style: tt.titleLarge?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
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
}

/// PromptPay EMVCo QR code card (`const PromptPayQR` in `prototype/index.html`
/// & `design/figma/payment_qris.png`).
class PromptPayQR extends StatelessWidget {
  const new({required this.promptpayId, required this.amount, super.key});
  final String promptpayId;
  final double amount;

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
            baht(amount, amount % 1 != 0 ? 2 : 0),
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

/// Transfer / card status card (`payment_card_waiting/success/failed.png`).
class TransferStatusSection extends StatelessWidget {
  const new({
    required this.methodName,
    required this.status,
    required this.onStatusChanged,
    super.key,
  });

  final String methodName;
  final String status;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final fail = status == 'failed';
    final ok = status == 'success';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Seg<String>(
          key: const ValueKey('transfer-status-seg'),
          value: status,
          items: const [
            SegItem(value: 'waiting', label: 'กำลังรอ'),
            SegItem(value: 'success', label: 'สำเร็จ'),
            SegItem(value: 'failed', label: 'ล้มเหลว'),
          ],
          onChanged: onStatusChanged,
        ),
        const SizedBox(height: AppDimensions.space3),
        Container(
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
                  color: fail ? t.dangerSoft : (ok ? t.primary : t.primarySoft),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon(
                    fail ? 'x' : (ok ? 'check' : 'clock'),
                    color: fail ? t.danger : (ok ? t.onPrimary : t.primaryInk),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.space2_5),
              Text(
                fail
                    ? 'ชำระเงินไม่สำเร็จ'
                    : (ok
                          ? 'ชำระเงินสำเร็จ'
                          : 'กำลังรอการชำระเงิน ($methodName)'),
                style: tt.titleMedium?.copyWith(color: fail ? t.danger : t.ink),
              ),
              const SizedBox(height: AppDimensions.space1),
              Text(
                fail
                    ? 'รายการไม่สำเร็จ กรุณาตรวจสอบกับลูกค้าอีกครั้ง'
                    : 'ตรวจสอบสลิปหรือยอดเงินเข้าบัญชีก่อนกดยืนยัน',
                textAlign: TextAlign.center,
                style: tt.labelSmall?.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
