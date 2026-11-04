import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

export 'package:app/features/sale/presentation/widgets/sale_summary_widgets.dart';

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
