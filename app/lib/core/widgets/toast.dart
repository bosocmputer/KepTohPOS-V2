import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Floating status toast banner (`.toast` in `prototype/index.html`).
class AppToast extends StatelessWidget {
  const new({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    final tokens = context.tokens;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space4_5,
          vertical: AppDimensions.space3,
        ),
        decoration: BoxDecoration(
          color: tokens.dark,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: tokens.shadows,
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: tokens.onDark, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Shows a transient [AppToast] via [ScaffoldMessenger].
void showAppToast(BuildContext context, String message) {
  final tokens = context.tokens;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.dark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        duration: const Duration(milliseconds: 2400),
        content: Text(
          message,
          style: TextStyle(
            color: tokens.onDark,
            fontSize: AppDimensions.fsBase,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
}
