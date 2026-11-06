import 'dart:math' as math;

import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Square PIN indicator boxes (`PinDots` in `prototype/index.html` &
/// `design/figma/login.png`) with iPhone-style shake feedback on error.
class PinDots extends StatelessWidget {
  const new({
    required this.value,
    super.key,
    this.length = 4,
    this.hasError = false,
    this.boxSize = AppDimensions.btnMdH,
    this.gap = AppDimensions.space3,
  });

  final String value;
  final int length;
  final bool hasError;
  final double boxSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Container(
            width: boxSize,
            height: boxSize,
            decoration: BoxDecoration(
              color: i < value.length
                  ? tokens.primarySoft
                  : hasError
                  ? tokens.dangerSoft.withValues(alpha: 0.45)
                  : (boxSize > AppDimensions.btnMdH
                        ? tokens.surface2
                        : tokens.surface),
              borderRadius: BorderRadius.circular(
                boxSize > AppDimensions.btnMdH
                    ? AppDimensions.radiusMd
                    : AppDimensions.radiusSm,
              ),
              border: Border.all(
                color: i < value.length
                    ? tokens.primary
                    : hasError
                    ? tokens.danger
                    : tokens.line,
                width: (i < value.length || hasError)
                    ? AppDimensions.borderBold
                    : (boxSize > AppDimensions.btnMdH
                          ? AppDimensions.borderThick
                          : AppDimensions.borderThin),
              ),
            ),
            child: i < value.length
                ? Center(
                    child: Container(
                      width: AppDimensions.pinDotSize,
                      height: AppDimensions.pinDotSize,
                      decoration: BoxDecoration(
                        color: tokens.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ],
    );

    return Semantics(
      label: 'ใส่แล้ว ${value.length} จาก $length หลัก',
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppDimensions.space2,
          bottom: AppDimensions.space4,
        ),
        child: TweenAnimationBuilder<double>(
          key: ValueKey<bool>(hasError),
          tween: Tween<double>(begin: 0, end: hasError ? 1 : 0),
          duration: const Duration(milliseconds: 360),
          builder: (context, t, child) {
            final dx = hasError
                ? math.sin(t * math.pi * 4) * (1 - t) * 10.0
                : 0.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: row,
        ),
      ),
    );
  }
}
