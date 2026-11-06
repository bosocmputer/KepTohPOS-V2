import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/page_header.dart';
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

/// Unified staff profile and shift status capsule chip (`StaffShiftChip`)
/// combining `Avatar`, staff display name, and shift status badge.
class StaffShiftChip extends StatelessWidget {
  const new({
    required this.staffName,
    required this.isShiftOpen,
    super.key,
    this.compact = false,
    this.onTap,
  });

  final String staffName;
  final bool isShiftOpen;
  final bool compact;
  final VoidCallback? onTap;

  String get _shortName => staffName.split(' ').first.trim();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final statusLabel = isShiftOpen ? 'กะเปิด' : 'ยังไม่เปิดกะ';

    final avatarWithDot = Stack(
      children: [
        Avatar(
          name: staffName,
          size: compact ? AppDimensions.tap : AppDimensions.avatarSm,
        ),
        Positioned(
          right: AppDimensions.space0,
          bottom: AppDimensions.space0,
          child: Container(
            width: AppDimensions.statusDotMd,
            height: AppDimensions.statusDotMd,
            decoration: BoxDecoration(
              color: isShiftOpen ? tokens.success : tokens.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: tokens.surface,
                width: AppDimensions.borderBold,
              ),
            ),
          ),
        ),
      ],
    );

    if (compact) {
      return Semantics(
        button: true,
        label: 'บัญชีและกะ · $staffName · $statusLabel',
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: avatarWithDot,
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'บัญชีและกะ · $staffName · $statusLabel',
      child: Material(
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(
            color: tokens.line,
            width: AppDimensions.borderThick,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: SizedBox(
            height: AppDimensions.tap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  avatarWithDot,
                  const SizedBox(width: AppDimensions.space2),
                  Flexible(
                    child: Text(
                      _shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space2),
                  Pill(
                    label: statusLabel,
                    tone: isShiftOpen ? PillTone.green : PillTone.neutral,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
