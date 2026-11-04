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

/// Order item row inside the Order Panel (`const OrderLine` in
/// `prototype/index.html` & `design/figma/cashier.png`).
class OrderLine extends StatelessWidget {
  const new({
    required this.name,
    required this.sub,
    required this.qty,
    super.key,
    this.onChanged,
    this.onRemove,
    this.removeLabel,
    this.removeOff = false,
  });

  final String name;
  final String sub;
  final int qty;
  final ValueChanged<int>? onChanged;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: tt.bodyMedium?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(sub, style: tt.labelSmall?.copyWith(color: t.muted)),
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

/// Calculated order breakdown (`const OrderSummary` in `prototype/index.html`).
/// Renders pre-computed values from `calcOrder` / `orderOf` without performing
/// any arithmetic in the UI.
class OrderSummary extends StatelessWidget {
  const new({
    required this.shop,
    required this.order,
    super.key,
    this.noTotal = false,
  });

  final ShopConfig shop;
  final CalculatedOrder order;
  final bool noTotal;

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
          if (order.lines.isEmpty)
            Text(
              'ยังไม่มีรายการ',
              style: tt.bodySmall?.copyWith(color: t.muted),
            )
          else
            for (final l in order.lines)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.spaceHalf,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${l.name} × ${l.qty}',
                        style: tt.bodySmall?.copyWith(color: t.ink),
                      ),
                    ),
                    Text(
                      fmt(l.qty * l.price),
                      style: tt.bodySmall?.copyWith(
                        color: t.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          if (order.service > 0)
            _SummaryRow(
              'ค่าบริการ ${fmtQ(shop.servicePct)}%',
              fmt(order.service, 2),
            ),
          if (shop.vatMode == 'excluded')
            _SummaryRow('VAT 7%', fmt(order.vat, 2)),
          if (order.rounding != 0)
            _SummaryRow('ปัดเศษ', fmt(order.rounding, 2)),
          if (!noTotal) ...[
            const SizedBox(height: AppDimensions.space2),
            Divider(color: t.line, height: 1),
            const SizedBox(height: AppDimensions.space2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ยอดชำระ',
                  style: tt.bodyMedium?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  baht(order.total, order.total % 1 != 0 ? 2 : 0),
                  style: tt.titleLarge?.copyWith(
                    color: t.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const new(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceHalf),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodySmall?.copyWith(color: t.muted)),
          Text(value, style: tt.bodySmall?.copyWith(color: t.ink)),
        ],
      ),
    );
  }
}
