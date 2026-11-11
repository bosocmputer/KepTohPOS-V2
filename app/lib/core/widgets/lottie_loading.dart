import 'package:app/core/data/supabase/network_activity.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Centered walking-orange Lottie animation used across loading states.
class WalkingOrangeLoader extends StatelessWidget {
  const new({
    this.size = 260,
    this.label,
    this.isOverlay = false,
    this.onScrim = false,
    super.key,
  });

  final double size;
  final String? label;
  final bool isOverlay;
  final bool onScrim;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = Column(
      key: const ValueKey('walking-orange-loader'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size * 0.78,
          child: Transform.scale(
            scale: 1.35,
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
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.space1),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: onScrim ? Colors.white : t.muted,
              fontWeight: onScrim ? FontWeight.w700 : FontWeight.w600,
              shadows: onScrim
                  ? const [
                      Shadow(
                        color: Color(0x8A000000),
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ],
    );
    if (isOverlay) return content;
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkActivity.instance.busy,
      builder: (context, isBusy, _) {
        if (isBusy) return SizedBox(width: size, height: size * 0.78);
        return content;
      },
    );
  }
}
