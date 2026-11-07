import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A small spinner and message shown under the PIN boxes while the PIN is
/// sent to the server, so a slow connection does not look like a frozen pad.
class PinCheckingHint extends StatelessWidget {
  const new({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      key: const ValueKey('pin-checking'),
      padding: const EdgeInsets.only(bottom: AppDimensions.space3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.primary),
          ),
          const SizedBox(width: AppDimensions.space2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}
