import 'package:app/core/data/local/connection_monitor.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/app_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Floating note that the device is offline or still sending data made
/// offline; hidden when everything is sent.
class SyncStatusBanner extends StatelessWidget {
  const new({required this.status, required this.child, super.key, this.onTap});

  final ValueListenable<SyncStatus> status;
  final Widget child;

  /// Opens the sync status sheet.
  final VoidCallback? onTap;

  static String _bills(int n) => n > 0 ? ' (บิล $n ใบ)' : '';

  static String? textFor(SyncStatus s) {
    final p = s.progress;
    if (p != null && !p.done) {
      return 'กำลังส่ง ${p.sent}/${p.total} รายการ'
          '${p.bills > 0 ? ' · บิล ${p.sentBills}/${p.bills} ใบ' : ''}';
    }
    if (!s.online) {
      return s.pending > 0
          ? 'ออฟไลน์ · ขายต่อได้ · รอส่ง ${s.pending} รายการ'
                '${_bills(s.pendingBills)}'
          : 'ออฟไลน์ · ขายต่อได้ ข้อมูลจะส่งเมื่อเน็ตกลับมา';
    }
    if (p != null && p.done) {
      return p.rejected > 0
          ? 'ส่งแล้ว ${p.sent} รายการ · ไม่ผ่าน ${p.rejected} รายการ '
                'ให้ผู้จัดการตรวจสอบ'
          : 'ส่งครบแล้ว ${p.sent} รายการ'
                '${p.sentBills > 0 ? ' · บิล ${p.sentBills} ใบ' : ''}';
    }
    if (s.pending > 0) {
      return 'กำลังส่งข้อมูลที่ค้าง ${s.pending} รายการ'
          '${_bills(s.pendingBills)}';
    }
    return null;
  }

  /// Green once everything went through, red when offline or refused.
  static SyncTone toneFor(SyncStatus s) {
    final p = s.progress;
    if (p != null && p.done && s.online) {
      return p.rejected > 0 ? SyncTone.bad : SyncTone.good;
    }
    if (!s.online && (p == null || p.done)) return SyncTone.bad;
    return SyncTone.busy;
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
          final (bg, fg, icon) = switch (toneFor(s)) {
            SyncTone.good => (t.successSoft, t.success, 'check'),
            SyncTone.bad => (t.dangerSoft, t.dangerInk, 'alert'),
            SyncTone.busy => (t.primarySoft, t.primary, 'clock'),
          };
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
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space3,
                      vertical: AppDimensions.space2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(icon, color: fg),
                        const SizedBox(width: AppDimensions.space2),
                        Text(
                          text,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
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

/// Colour of the sync banner.
enum SyncTone { good, bad, busy }
