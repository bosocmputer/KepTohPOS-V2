import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

/// Customer head count row (`const PeopleRow` in `prototype/index.html`).
class PeopleRow extends StatelessWidget {
  const new({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
    super.key,
    this.stepperKey,
  });

  final String label;
  final String sub;
  final int value;
  final ValueChanged<int> onChanged;
  final Key? stepperKey;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space1_5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.bodyMedium?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(sub, style: tt.labelSmall?.copyWith(color: t.muted)),
              ],
            ),
          ),
          PosStepper(
            key: stepperKey,
            label: label,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Order item row inside the Order Panel (`const OrderLine`).
class OrderLine extends StatelessWidget {
  const new({
    required this.name,
    required this.sub,
    required this.qty,
    super.key,
    this.icon = 'drink',
    this.onChanged,
    this.onNoteTap,
    this.onRemove,
    this.removeLabel,
    this.removeOff = false,
  });

  final String name;
  final String sub;
  final int qty;
  final String icon;
  final ValueChanged<int>? onChanged;
  final VoidCallback? onNoteTap;
  final VoidCallback? onRemove;
  final String? removeLabel;
  final bool removeOff;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space1_5),
      child: Row(
        children: [
          Container(
            width: AppDimensions.avatarSm,
            height: AppDimensions.avatarSm,
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Center(
              child: AppIcon(icon, size: AppDimensions.iconSm, color: t.muted),
            ),
          ),
          const SizedBox(width: AppDimensions.space2_5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Text(sub, style: tt.labelSmall?.copyWith(color: t.muted)),
                    if (onNoteTap != null) ...[
                      const SizedBox(width: AppDimensions.space2),
                      InkWell(
                        onTap: onNoteTap,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusXs,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(
                            AppDimensions.spaceHalf,
                          ),
                          decoration: BoxDecoration(
                            color: t.surface2,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusXs,
                            ),
                            border: Border.all(color: t.line),
                          ),
                          child: AppIcon(
                            'edit',
                            size: AppDimensions.iconXs,
                            color: t.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onChanged != null)
            PosStepper(label: name, value: qty, onChanged: onChanged!)
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space2,
              ),
              child: Text(
                '× $qty',
                style: tt.bodyMedium?.copyWith(
                  color: t.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (onRemove != null) ...[
            const SizedBox(width: AppDimensions.space2),
            Btn(
              size: BtnSize.sm,
              kind: BtnKind.danger,
              icon: 'trash',
              semanticLabel: removeLabel ?? 'ลบ $name',
              disabled: removeOff,
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

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
          if (shop.vatMode == 'excluded' && order.vat > 0)
            _row(context, 'VAT 7%', baht(order.vat, 2)),
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
