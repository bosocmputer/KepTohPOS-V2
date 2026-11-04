import 'dart:async';

import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Floating status toast banner (`.toast` in `prototype/index.html`).
/// Used as the visual card inside [AppToastService] and `/dev/components`.
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

/// Single root-overlay toast service for the entire application.
///
/// - Auto-dismisses after `2.5` seconds (`2500ms`) regardless of open modals,
///   drawers, route changes, or widget rebuilds.
/// - Shows at most one toast at a time; a new toast immediately replaces the
///   previous one.
/// - Positioned at top-center below the Topbar (`SafeArea`-aware) so it never
///   covers action buttons in drawers, modals, or right panels.
/// - Tapping the toast dismisses it immediately.
abstract final class AppToastService {
  static const Duration defaultDuration = Duration(milliseconds: 2500);

  static OverlayEntry? _entry;

  /// Whether a toast is currently visible on the root overlay.
  static bool get isShowing => _entry != null;

  /// Shows [message] at top-center below the Topbar and auto-dismisses after
  /// [duration].
  static void show(
    BuildContext context,
    String message, {
    Duration duration = defaultDuration,
  }) {
    if (message.trim().isEmpty) return;
    dismiss();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || !overlay.mounted) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _ToastOverlayHost(
        message: message,
        duration: duration,
        onDismiss: () {
          if (identical(_entry, entry)) {
            dismiss();
          }
        },
        onHostDisposed: () {
          if (identical(_entry, entry)) {
            _entry = null;
          }
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Immediately removes the active toast, if any.
  static void dismiss() {
    final current = _entry;
    _entry = null;
    if (current != null && current.mounted) {
      current
        ..remove()
        ..dispose();
    }
  }
}

class _ToastOverlayHost extends StatefulWidget {
  const new({
    required this.message,
    required this.duration,
    required this.onDismiss,
    required this.onHostDisposed,
  });

  final String message;
  final Duration duration;
  final VoidCallback onDismiss;
  final VoidCallback onHostDisposed;

  @override
  State<_ToastOverlayHost> createState() => _ToastOverlayHostState();
}

class _ToastOverlayHostState extends State<_ToastOverlayHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    widget.onHostDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topOffset =
        mq.padding.top +
        AppDimensions.topbarHeight(mq.size.width, mq.size.height) +
        AppDimensions.space3;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: topOffset,
          left: AppDimensions.space4,
          right: AppDimensions.space4,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            key: const ValueKey('app-toast-dismiss'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: AppToast(
              key: const ValueKey('active-app-toast'),
              message: widget.message,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a transient [AppToast] via [AppToastService] on the root [Overlay].
void showAppToast(BuildContext context, String message) {
  AppToastService.show(context, message);
}
