import 'package:app/core/theme/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows a progress bar along the top and blocks taps while [busy] is `true`,
/// so staff can see the app is waiting and cannot submit the same thing twice.
class BusyOverlay extends StatelessWidget {
  const new({required this.busy, required this.child, super.key});

  final ValueListenable<bool> busy;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      ValueListenableBuilder<bool>(
        valueListenable: busy,
        builder: (context, isBusy, _) {
          if (!isBusy) return const SizedBox.shrink();
          return Positioned.fill(
            key: const ValueKey('busy-overlay'),
            child: Stack(
              children: [
                const ModalBarrier(dismissible: false),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: context.tokens.primary,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}
