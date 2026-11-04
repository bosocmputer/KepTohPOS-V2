import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Color tone for [Pill] (`tone` in `prototype/index.html`).
enum PillTone { neutral, orange, green, red }

/// Status badge / pill component (`Pill` in `prototype/index.html` & Figma).
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
    final (bg, fg, border) = switch (tone) {
      PillTone.orange => (
        tokens.primarySoft,
        tokens.primaryInk,
        tokens.primarySoft,
      ),
      PillTone.green => (
        tokens.successSoft,
        tokens.successInk,
        tokens.successSoft,
      ),
      PillTone.red => (tokens.dangerSoft, tokens.dangerInk, tokens.dangerSoft),
      PillTone.neutral => (tokens.surface2, tokens.muted, tokens.line),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space2_5,
        vertical: AppDimensions.space1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: AppDimensions.statusDotSm,
              height: AppDimensions.statusDotSm,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppDimensions.space1_5),
          ],
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
