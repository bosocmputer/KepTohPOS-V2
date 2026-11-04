import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Item in a [Seg] segmented control (`[key, label]` in `index.html`).
class SegItem<T> {
  const new({required this.value, required this.label});

  final T value;
  final String label;
}

/// Segmented control (`Seg` in `prototype/index.html`).
class Seg<T> extends StatelessWidget {
  const new({
    required this.items,
    required this.value,
    required this.onChanged,
    super.key,
    this.label,
    this.expanded = false,
  });

  final List<SegItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  final String? label;
  final bool expanded;

  Widget _buildSegment(
    BuildContext context,
    AppTokens tokens,
    SegItem<T> item,
  ) {
    final selected = item.value == value;
    return Container(
      decoration: BoxDecoration(
        color: selected ? tokens.surface : tokens.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        boxShadow: selected ? tokens.shadows : null,
      ),
      child: Material(
        color: tokens.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: InkWell(
          onTap: () => onChanged(item.value),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded
                  ? AppDimensions.space2
                  : AppDimensions.space3_5,
              vertical: AppDimensions.space2,
            ),
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? tokens.ink : tokens.muted,
                fontSize: AppDimensions.fsSm,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space1),
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: tokens.line),
        ),
        child: expanded
            ? Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppDimensions.spaceHalf),
                    Expanded(child: _buildSegment(context, tokens, items[i])),
                  ],
                ],
              )
            : Wrap(
                spacing: AppDimensions.spaceHalf,
                runSpacing: AppDimensions.spaceHalf,
                children: [
                  for (final item in items)
                    _buildSegment(context, tokens, item),
                ],
              ),
      ),
    );
  }
}
