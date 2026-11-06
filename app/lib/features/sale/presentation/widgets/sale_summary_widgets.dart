import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

/// Selectable payment method cards (`const PaymentPicker`).
class PaymentPicker extends StatelessWidget {
  const new({
    required this.methods,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<PaymentMethod> methods;
  final String value;
  final ValueChanged<String> onChanged;

  static String _shortMethodLabel(PaymentMethod m) {
    final name = m.name.trim();
    if (name == 'โอนเข้าบัญชีร้าน' || name.startsWith('โอนเข้าบัญชี')) {
      return 'โอนเงิน';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final active = methods.where((m) => m.active).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < active.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimensions.space2),
          Expanded(
            child: Material(
              color: active[i].id == value ? t.primarySoft : t.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                side: BorderSide(
                  color: active[i].id == value ? t.primary : t.line,
                  width: active[i].id == value
                      ? AppDimensions.borderBold
                      : AppDimensions.borderThin,
                ),
              ),
              child: InkWell(
                key: ValueKey('pay-method-${active[i].id}'),
                onTap: () => onChanged(active[i].id),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.space2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        AppIcons.forPaymentType(active[i].type),
                        color: active[i].id == value ? t.primaryInk : t.muted,
                      ),
                      const SizedBox(height: AppDimensions.space1),
                      Text(
                        _shortMethodLabel(active[i]),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: tt.labelSmall?.copyWith(
                          color: active[i].id == value ? t.primaryInk : t.ink,
                          fontWeight: active[i].id == value
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Selectable bank account cards for transfer payments (`BankAccountItem`).
class BankAccountPicker extends StatelessWidget {
  const new({
    required this.accounts,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<BankAccountItem> accounts;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    if (accounts.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('bank-account-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'เลือกบัญชีธนาคารที่รับโอน',
          style: tt.labelSmall?.copyWith(
            color: t.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppDimensions.space1_5),
        for (var i = 0; i < accounts.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimensions.space2),
          Material(
            color: accounts[i].id == value ? t.primarySoft : t.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              side: BorderSide(
                color: accounts[i].id == value ? t.primary : t.line,
                width: accounts[i].id == value
                    ? AppDimensions.borderBold
                    : AppDimensions.borderThin,
              ),
            ),
            child: InkWell(
              key: ValueKey('bank-account-${accounts[i].id}'),
              onTap: () => onChanged(accounts[i].id),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space3,
                  vertical: AppDimensions.space2_5,
                ),
                child: Row(
                  children: [
                    AppIcon(
                      'bank',
                      size: AppDimensions.iconLg,
                      color: accounts[i].id == value ? t.primary : t.muted,
                    ),
                    const SizedBox(width: AppDimensions.space2_5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            accounts[i].bankName,
                            style: tt.bodySmall?.copyWith(
                              color: accounts[i].id == value
                                  ? t.primaryInk
                                  : t.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            accounts[i].accountName.isNotEmpty
                                ? '${accounts[i].accountNo} · '
                                      '${accounts[i].accountName}'
                                : accounts[i].accountNo,
                            style: tt.labelSmall?.copyWith(color: t.muted),
                          ),
                        ],
                      ),
                    ),
                    if (accounts[i].id == value)
                      AppIcon('check', color: t.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppDimensions.space2),
        Text(
          'ตรวจสอบสลิปหรือยอดเงินเข้าบัญชีที่เลือกก่อนกดยืนยันรับเงินโอน',
          style: tt.labelSmall?.copyWith(color: t.muted),
        ),
      ],
    );
  }
}

/// Calculated order breakdown (`const OrderSummary` in `prototype/index.html`).
class OrderSummary extends StatelessWidget {
  const new({
    required this.shop,
    required this.order,
    super.key,
    this.noTotal = false,
    this.showLines = true,
  });

  final ShopConfig shop;
  final CalculatedOrder order;
  final bool noTotal;
  final bool showLines;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space3),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLines)
            if (order.lines.isEmpty)
              Text(
                'ยังไม่มีรายการ',
                style: tt.bodySmall?.copyWith(color: t.muted),
              )
            else
              for (final l in order.lines)
                _row(context, '${l.name} × ${l.qty}', baht(l.qty * l.price)),
          if (order.subtotal > 0) _row(context, 'ยอดรวม', baht(order.subtotal)),
          if (order.service > 0)
            _row(
              context,
              'ค่าบริการ ${fmtQ(shop.servicePct)}%',
              baht(order.service, 2),
            ),
          if (shop.vatMode != 'none' && order.vat > 0) ...[
            _row(context, 'มูลค่าก่อนภาษี', baht(order.total - order.vat, 2)),
            _row(
              context,
              'VAT ${fmtQ(shop.vatRate)}% '
              '(${shop.vatMode == "included" ? "รวมในราคา" : "แยกนอก"})',
              baht(order.vat, 2),
            ),
          ],
          if (order.rounding != 0)
            _row(context, 'ปัดเศษ', baht(order.rounding, 2)),
          if (!noTotal) ...[
            Divider(color: t.line, height: AppDimensions.space4),
            _row(
              context,
              'ยอดชำระ',
              baht(order.total, order.total % 1 != 0 ? 2 : 0),
              hi: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext ctx, String k, String v, {bool hi = false}) {
    final t = ctx.tokens;
    final tt = Theme.of(ctx).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceHalf),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              k,
              style: (hi ? tt.bodyMedium : tt.bodySmall)?.copyWith(
                color: hi ? t.ink : t.muted,
                fontWeight: hi ? FontWeight.w700 : null,
              ),
            ),
          ),
          Text(
            v,
            style: (hi ? tt.titleLarge : tt.bodySmall)?.copyWith(
              color: hi ? t.primary : t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
