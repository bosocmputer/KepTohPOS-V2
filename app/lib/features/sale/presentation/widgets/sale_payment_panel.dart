import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:app/features/sale/presentation/widgets/sale_payment_methods.dart';
import 'package:app/features/sale/presentation/widgets/sale_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/sale/presentation/widgets/sale_payment_methods.dart';

/// Mobile bottom sticky order bar for `SalePage`.
Widget buildSaleMobileBottomBar(
  BuildContext context,
  SaleState state,
  DiningTable tb,
  ScrollController scrollCtrl,
) {
  final t = context.tokens;
  final payTotal = state.payOrder.total;
  final s = Theme.of(context).textTheme.bodyMedium
      ?.copyWith(color: t.onPrimary, fontWeight: FontWeight.w700);
  return InkWell(
    key: const ValueKey('mobile-view-order-bar'),
    onTap: () => scrollCtrl.animateTo(
      scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    ),
    child: ColoredBox(
      color: t.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space4,
          vertical: AppDimensions.space3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ดูออเดอร์โต๊ะ ${tb.name}', style: s),
            Text('${baht(payTotal, payTotal % 1 != 0 ? 2 : 0)} ›', style: s),
          ],
        ),
      ),
    ),
  );
}

/// Payment step panel (`const PayStep` & `const PromptPayQR` in
/// `prototype/index.html` & `design/figma/payment_*.png`).
class SalePaymentPanel extends StatelessWidget {
  const new({
    required this.state,
    required this.staff,
    super.key,
    this.fullHeight = false,
  });

  final SaleState state;
  final StaffMember staff;
  final bool fullHeight;

  static List<double> quickCashAmounts(double total) {
    final roundedHundred = (total / 100).ceil() * 100.0;
    final candidates = <double>[total, roundedHundred, 500, 1000, 2000];
    final unique = <double>[];
    for (final v in candidates) {
      if (v >= total && !unique.contains(v)) unique.add(v);
    }
    return unique.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final bloc = context.read<SaleBloc>();
    final s = state.posState;
    final tb = state.table;
    final payOrder = state.payOrder;
    final method = state.activePaymentMethod;
    final note = state.effectiveNotes;
    if (tb == null || method == null) return const SizedBox.shrink();

    final screenH = MediaQuery.sizeOf(context).height;
    final compactH = screenH < 900;
    final gap = compactH ? AppDimensions.space2 : AppDimensions.space3;
    final vPad = compactH ? AppDimensions.space3 : AppDimensions.space4;

    final confirmLabel = switch (method.type) {
      'cash' => 'ยืนยันรับเงินสด',
      'qr' => 'ได้รับเงินแล้ว · ออกใบเสร็จ',
      _ => 'ยืนยันรับเงินโอน · ออกใบเสร็จ',
    };

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.space4,
        vertical: vPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppDimensions.space2),
              decoration: BoxDecoration(
                color: t.surface2,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Text(
                'โน้ตลูกค้า: $note',
                style: tt.bodySmall?.copyWith(color: t.ink),
              ),
            ),
            SizedBox(height: gap),
          ],
          OrderSummary(shop: s.shop, order: payOrder, showLines: !compactH),
          SizedBox(height: gap),
          Text(
            'วิธีชำระเงิน',
            style: tt.labelSmall?.copyWith(
              color: t.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.space1),
          PaymentPicker(
            methods: s.payments,
            value: method.id,
            onChanged: (id) => bloc.add(SalePaymentMethodSelected(id)),
          ),
          SizedBox(height: gap),
          if (method.type == 'cash')
            CashPaymentSection(state: state, staff: staff, compact: compactH)
          else if (method.type == 'qr')
            PromptPayQR(promptpayId: s.shop.promptpay, amount: payOrder.total)
          else if (method.type == 'transfer' &&
              state.activeBankAccounts.isNotEmpty)
            BankAccountPicker(
              accounts: state.activeBankAccounts,
              value: state.activeBankAccount?.id ?? '',
              onChanged: (id) => bloc.add(SaleBankAccountSelected(id)),
            )
          else
            TransferStatusSection(
              methodName: method.name,
              bankAccount: method.type == 'transfer'
                  ? state.activeBankAccount
                  : null,
            ),
        ],
      ),
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: fullHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.space4,
            vertical: compactH ? AppDimensions.space2 : AppDimensions.space4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'ชำระเงิน · โต๊ะ ${tb.name}',
                    style: tt.titleLarge?.copyWith(color: t.ink),
                  ),
                  const SizedBox(width: AppDimensions.space2),
                  Pill(
                    label: state.effectiveTiming == 'after'
                        ? 'กินก่อนจ่าย'
                        : 'จ่ายก่อนกิน',
                    tone: state.effectiveTiming == 'after'
                        ? PillTone.orange
                        : PillTone.green,
                  ),
                ],
              ),
              Btn(
                key: const ValueKey('pay-back-btn'),
                kind: BtnKind.ghost,
                icon: 'x',
                semanticLabel: 'กลับไปแก้รายการ',
                onPressed: () =>
                    bloc.add(const SalePaymentStepChanged('order')),
              ),
            ],
          ),
        ),
        Divider(color: t.line, height: 1),
        if (fullHeight)
          Expanded(child: SingleChildScrollView(child: content))
        else
          content,
        Divider(color: t.line, height: 1),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.space4,
            vertical: vPad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Btn(
                key: const ValueKey('pay-confirm-btn'),
                kind: BtnKind.primary,
                size: BtnSize.lg,
                block: true,
                icon: 'check',
                label: confirmLabel,
                disabled: !state.canConfirmPayment,
                onPressed: () => bloc.add(SalePaymentSubmitted(staff: staff)),
              ),
              const SizedBox(height: AppDimensions.space2),
              Btn(
                key: const ValueKey('pay-cancel-btn'),
                label: 'กลับไปแก้รายการ',
                block: true,
                onPressed: () =>
                    bloc.add(const SalePaymentStepChanged('order')),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      key: const ValueKey('sale-payment-panel'),
      height: fullHeight ? double.infinity : null,
      decoration: fullHeight
          ? BoxDecoration(
              color: t.surface,
              border: Border(left: BorderSide(color: t.line)),
            )
          : BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: t.line),
            ),
      child: fullHeight ? SafeArea(left: false, child: column) : column,
    );
  }
}
