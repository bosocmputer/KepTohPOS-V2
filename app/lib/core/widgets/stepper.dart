import 'dart:math' as math;

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';

/// Plus / minus numeric stepper (`Stepper` in `prototype/index.html` & Figma).
class PosStepper extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    super.key,
    this.min = 0,
    this.label,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final canDecrement = value > min;
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: 'minus',
            semanticLabel: 'ลด',
            enabled: canDecrement,
            onTap: () => onChanged(math.max(min, value - 1)),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: AppDimensions.space9),
            child: Center(
              child: Text(
                '$value',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: tokens.ink, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          _StepBtn(
            icon: 'plus',
            semanticLabel: 'เพิ่ม',
            enabled: true,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const new({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  final String icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            child: const SizedBox(
              width: AppDimensions.btnSmH,
              height: AppDimensions.btnSmH,
              child: Center(
                child: AppIcon('minus', size: AppDimensions.iconSm),
              ),
            ),
          ),
        ),
      ),
    )._withIcon(icon, tokens.ink);
  }
}

extension on Widget {
  Widget _withIcon(String iconName, Color color) => Builder(
    builder: (context) {
      final sem = this as Semantics;
      final op = sem.child! as Opacity;
      final mat = op.child! as Material;
      final ink = mat.child! as InkWell;
      return Semantics(
        button: true,
        enabled: sem.properties.enabled,
        label: sem.properties.label,
        child: Opacity(
          opacity: op.opacity,
          child: Material(
            color: mat.color,
            borderRadius: mat.borderRadius,
            child: InkWell(
              onTap: ink.onTap,
              borderRadius: ink.borderRadius,
              child: SizedBox(
                width: AppDimensions.btnSmH,
                height: AppDimensions.btnSmH,
                child: Center(
                  child: AppIcon(
                    iconName,
                    size: AppDimensions.iconSm,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
