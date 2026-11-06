import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Value tone for [Stat] (`tone` in `prototype/index.html`).
enum StatTone { neutral, green, red }

/// Summary metric item (`Stat` in `prototype/index.html`).
class Stat extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    super.key,
    this.sub,
    this.tone = StatTone.neutral,
  });

  final String label;
  final String value;
  final String? sub;
  final StatTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final valueColor = switch (tone) {
      StatTone.green => tokens.successInk,
      StatTone.red => tokens.dangerInk,
      StatTone.neutral => tokens.ink,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space5,
        vertical: AppDimensions.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: tokens.muted,
              fontSize: AppDimensions.fsXs,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceHalf),
          Text(
            value,
            style: textTheme.displayMedium?.copyWith(
              color: valueColor,
              fontSize: AppDimensions.fs3xl,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (sub != null && sub!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spaceHalf),
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: tokens.muted,
                fontSize: AppDimensions.fsSm,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grouped container of [Stat] items separated by thin vertical dividers
/// (`.stats` in `prototype/index.html`).
class StatsGroup extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: tokens.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedWidth &&
              constraints.maxWidth >= 680 &&
              children.isNotEmpty) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Container(
                        width: AppDimensions.borderThin,
                        color: tokens.line,
                      ),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
            );
          }
          return Wrap(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Container(
                    width: AppDimensions.borderThin,
                    height: AppDimensions.btnLgH,
                    margin: const EdgeInsets.symmetric(
                      vertical: AppDimensions.space3,
                    ),
                    color: tokens.line,
                  ),
                children[i],
              ],
            ],
          );
        },
      ),
    );
  }
}
