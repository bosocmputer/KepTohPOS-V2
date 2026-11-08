import 'package:app/core/data/local/connection_monitor.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/app_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Floating note that the device is offline or still sending data made
/// offline; hidden when everything is sent.
class SyncStatusBanner extends StatelessWidget {
  const new({required this.status, required this.child, super.key});

  final ValueListenable<SyncStatus> status;
  final Widget child;

  static String? textFor(SyncStatus s) {
    if (!s.online) {
      return s.pending > 0
          ? 'ออฟไลน์ · รอส่ง ${s.pending} รายการเมื่อเน็ตกลับมา'
          : 'ออฟไลน์ · ตรวจการเชื่อมต่ออินเทอร์เน็ต';
    }
    if (s.pending > 0) return 'กำลังส่งข้อมูลที่ค้าง ${s.pending} รายการ';
    return null;
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      ValueListenableBuilder<SyncStatus>(
        valueListenable: status,
        builder: (context, s, _) {
          final text = textFor(s);
          if (text == null) return const SizedBox.shrink();
          final t = context.tokens;
          final narrow = MediaQuery.sizeOf(context).width < 600;
          final bg = s.online ? t.primarySoft : t.dangerSoft;
          final fg = s.online ? t.primary : t.dangerInk;
          return Positioned(
            left: 0,
            right: 0,
            bottom: (narrow ? 80 : 16) + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: Material(
                key: const ValueKey('sync-status-banner'),
                color: bg,
                elevation: 2,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space3,
                    vertical: AppDimensions.space2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(s.online ? 'clock' : 'alert', color: fg),
                      const SizedBox(width: AppDimensions.space2),
                      Text(
                        text,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}
