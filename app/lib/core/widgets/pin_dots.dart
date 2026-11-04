import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// PIN indicator dots (`PinDots` in `prototype/index.html` & Figma Login).
class PinDots extends StatelessWidget {
  const new({required this.value, super.key, this.length = 4});

  final String value;
  final int length;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: 'ใส่แล้ว ${value.length} จาก $length หลัก',
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppDimensions.space2,
          bottom: AppDimensions.space4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < length; i++) ...[
              if (i > 0) const SizedBox(width: AppDimensions.space3),
              Container(
                width: AppDimensions.pinDotSize,
                height: AppDimensions.pinDotSize,
                decoration: BoxDecoration(
                  color: i < value.length
                      ? tokens.primary
                      : tokens.surface.withValues(alpha: 0),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i < value.length ? tokens.primary : tokens.muted,
                    width: AppDimensions.borderBold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
