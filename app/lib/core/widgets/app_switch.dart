import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Accessible token-styled toggle switch (`.toggle` in `prototype/index.html`).
class AppSwitch extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    super.key,
    this.label,
    this.subtitle,
    this.semanticLabel,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? subtitle;
  final String? semanticLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final canTap = enabled && onChanged != null;

    final track = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: 44,
      height: 24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value
            ? (canTap ? t.primary : t.primary.withValues(alpha: 0.5))
            : t.surface2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        border: Border.all(color: value ? t.primary : t.line),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: value ? AppRawTokens.white : t.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );

    if (label == null || label!.isEmpty) {
      return Semantics(
        label: semanticLabel,
        toggled: value,
        enabled: canTap,
        button: true,
        child: InkWell(
          onTap: canTap ? () => onChanged!(!value) : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: track,
          ),
        ),
      );
    }

    return Semantics(
      label: semanticLabel ?? label,
      toggled: value,
      enabled: canTap,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canTap ? () => onChanged!(!value) : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppDimensions.tap),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.space1_5,
                horizontal: AppDimensions.space2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  track,
                  const SizedBox(width: AppDimensions.space2_5),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label!,
                          style: tt.bodyMedium?.copyWith(
                            color: t.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(
                            subtitle!,
                            style: tt.labelSmall?.copyWith(color: t.muted),
                          ),
                      ],
                    ),
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
