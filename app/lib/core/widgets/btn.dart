import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';

/// Visual variants for [Btn] (`kind` in `prototype/index.html`).
enum BtnKind { normal, primary, dark, danger, dangerSolid, ghost }

/// Size variants for [Btn] (`size` in `prototype/index.html`).
enum BtnSize { sm, md, lg }

/// Shared button component (`Btn` in `prototype/index.html` & Figma kit).
class Btn extends StatelessWidget {
  const new({
    super.key,
    this.label,
    this.child,
    this.icon,
    this.kind = BtnKind.normal,
    this.size = BtnSize.md,
    this.block = false,
    this.disabled = false,
    this.onPressed,
    this.semanticLabel,
  });

  final String? label;
  final Widget? child;
  final String? icon;
  final BtnKind kind;
  final BtnSize size;
  final bool block;
  final bool disabled;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  bool get _isIconOnly => label == null && child == null && icon != null;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = !disabled && onPressed != null;

    final (bgColor, fgColor, borderColor, fontWeight) = switch (kind) {
      BtnKind.primary => (
        tokens.primary,
        tokens.onPrimary,
        tokens.primary,
        FontWeight.w600,
      ),
      BtnKind.dark => (
        tokens.dark,
        tokens.onDark,
        tokens.dark,
        FontWeight.w600,
      ),
      BtnKind.dangerSolid => (
        tokens.danger,
        AppRawTokens.white,
        tokens.danger,
        FontWeight.w600,
      ),
      BtnKind.danger => (
        tokens.dangerSoft,
        tokens.dangerInk,
        tokens.dangerSoft,
        FontWeight.w500,
      ),
      BtnKind.ghost => (
        tokens.surface.withValues(alpha: 0),
        tokens.ink,
        tokens.line.withValues(alpha: 0),
        FontWeight.w500,
      ),
      BtnKind.normal => (
        tokens.surface,
        tokens.ink,
        tokens.line,
        FontWeight.w500,
      ),
    };

    final (minHeight, hPad, fontSize, radius) = switch (size) {
      BtnSize.sm => (
        AppDimensions.btnSmH,
        AppDimensions.space3,
        AppDimensions.fsSm,
        AppDimensions.radiusMd,
      ),
      BtnSize.md => (
        AppDimensions.btnMdH,
        AppDimensions.space4,
        AppDimensions.fsBase,
        AppDimensions.radiusMd,
      ),
      BtnSize.lg => (
        AppDimensions.btnLgH,
        AppDimensions.space6,
        AppDimensions.fsLg,
        AppDimensions.radiusMd,
      ),
    };

    final content = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null)
          AppIcon(icon!, size: AppDimensions.iconSm, color: fgColor),
        if (icon != null && (label != null || child != null))
          const SizedBox(width: AppDimensions.space1_5),
        if (child != null)
          DefaultTextStyle.merge(
            style: TextStyle(
              color: fgColor,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
            child: child!,
          )
        else if (label != null)
          Flexible(
            child: Text(
              label!,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: fgColor,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
            ),
          ),
      ],
    );

    final buttonWidget = Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: borderColor,
            width: AppDimensions.borderThick,
          ),
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(radius),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight,
              minWidth: _isIconOnly ? minHeight : AppDimensions.space0,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _isIconOnly ? AppDimensions.space0 : hPad,
              ),
              child: Center(
                widthFactor: block ? null : 1,
                heightFactor: 1,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );

    final wrapped = block
        ? SizedBox(width: double.infinity, child: buttonWidget)
        : buttonWidget;

    if (semanticLabel != null) {
      return Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel,
        child: wrapped,
      );
    }
    return wrapped;
  }
}
