import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/lottie_loading.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shows a progress bar along the top, a centered walking-orange loader card,
/// and blocks taps while [busy] is `true`, so staff can see the app is waiting
/// and cannot submit the same thing twice.
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
          final tokens = context.tokens;
          return Positioned.fill(
            key: const ValueKey('busy-overlay'),
            child: Stack(
              children: [
                ModalBarrier(dismissible: false, color: tokens.scrim),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: tokens.primary,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                const IgnorePointer(
                  child: Material(
                    type: MaterialType.transparency,
                    child: Center(
                      child: OverflowBox(
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        child: WalkingOrangeLoader(
                          label: 'กำลังประมวลผล…',
                          isOverlay: true,
                          onScrim: true,
                        ),
                      ),
                    ),
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
