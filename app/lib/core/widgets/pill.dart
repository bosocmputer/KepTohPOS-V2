import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Color tone for [Pill] (`tone` in `prototype/index.html`).
enum PillTone { neutral, orange, green, red }

/// Status badge / pill component (`Pill` in `prototype/index.html` & Figma
/// Order Status / Stock Status in `design/figma/cashier.png` &
/// `design/figma/supply_list.png`): small rounded rectangle with soft fill
/// and no dot.
class Pill extends StatelessWidget {
  const new({
    super.key,
    this.label,
    this.child,
    this.tone = PillTone.neutral,
    this.showDot = false,
  });

  final String? label;
  final Widget? child;
  final PillTone tone;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (bg, fg) = switch (tone) {
      PillTone.orange => (tokens.primarySoft, tokens.primaryInk),
      PillTone.green => (tokens.successSoft, tokens.successInk),
      PillTone.red => (tokens.dangerSoft, tokens.dangerInk),
      PillTone.neutral => (tokens.surface2, tokens.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space2,
        vertical: AppDimensions.space1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (child != null)
            DefaultTextStyle.merge(
              style: TextStyle(
                color: fg,
                fontSize: AppDimensions.fsXs,
                fontWeight: FontWeight.w600,
              ),
              child: child!,
            )
          else if (label != null)
            Text(
              label!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontSize: AppDimensions.fsXs,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
