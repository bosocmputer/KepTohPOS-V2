import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Centered walking-orange Lottie animation used across loading states.
class WalkingOrangeLoader extends StatelessWidget {
  const new({this.size = 136, this.label, super.key});

  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      key: const ValueKey('walking-orange-loader'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Lottie.asset(
            'assets/Walking_Orange.json',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: t.primary,
                ),
              ),
            ),
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.space2),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: t.muted, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
