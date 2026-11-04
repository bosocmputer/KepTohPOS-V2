import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';

/// Item in a [Tabs] bar (`[key, label, count?]` in `prototype/index.html`).
class TabItem<T> {
  const new({required this.value, required this.label, this.count, this.icon});

  final T value;
  final String label;
  final int? count;
  final String? icon;
}

/// Category / section tabs (`Tabs` in `prototype/index.html` & Figma Cashier).
class Tabs<T> extends StatelessWidget {
  const new({
    required this.items,
    required this.value,
    required this.onChanged,
    super.key,
    this.label,
  });

  final List<TabItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: label,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: AppDimensions.space2_5),
              _buildTabCard(context, items[i], tokens, textTheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabCard(
    BuildContext context,
    TabItem<T> item,
    AppTokens tokens,
    TextTheme textTheme,
  ) {
    final selected = item.value == value;
    return Material(
      color: selected ? tokens.primarySoft : tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(
          color: selected ? tokens.primary : tokens.line,
          width: AppDimensions.borderThick,
        ),
      ),
      child: InkWell(
        onTap: () => onChanged(item.value),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppDimensions.tap),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space3_5,
              vertical: AppDimensions.space2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon != null) ...[
                  Container(
                    width: AppDimensions.space8,
                    height: AppDimensions.space8,
                    decoration: BoxDecoration(
                      color: selected ? tokens.primary : tokens.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppIcon(
                        item.icon!,
                        size: AppDimensions.iconXs,
                        color: selected ? tokens.onPrimary : tokens.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space2_5),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: selected ? tokens.primaryInk : tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.count != null)
                      Text(
                        '(${item.count})',
                        style: textTheme.labelSmall?.copyWith(
                          color: selected ? tokens.primaryInk : tokens.muted,
                          fontSize: AppDimensions.fsXs,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
