import 'dart:async';

import 'package:app/core/sync/sync_center.dart';
import 'package:app/core/sync/sync_describe.dart';
import 'package:app/core/sync/sync_status_sheet.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Header chip showing whether data reached the server; opens the status
/// sheet. Hidden in mock mode.
class SyncStatusButton extends StatelessWidget {
  const new({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final center = SyncCenter.maybe;
    if (center == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        center.entries,
        center.status,
        center.lastSynced,
      ]),
      builder: (context, _) {
        final t = context.tokens;
        final now = DateTime.now();
        final all = center.entries.value;
        final refused = all.where((e) => e.rejected).length;
        final waiting = all.length - refused;
        final last = center.lastSynced.value;
        final online = center.status.value.online;
        final (icon, fg, bg, label) = !online
            ? (
                'wifi-off',
                t.dangerInk,
                t.dangerSoft,
                waiting > 0 ? 'ออฟไลน์ · รอส่ง $waiting' : 'ออฟไลน์',
              )
            : refused > 0
            ? ('alert', t.dangerInk, t.dangerSoft, 'ส่งไม่ผ่าน $refused')
            : waiting > 0
            ? ('cloud-upload', t.primaryInk, t.primarySoft, 'รอส่ง $waiting')
            : ('cloud-done', t.successInk, t.successSoft, 'ส่งครบ');
        final stale = center.isStale(now);
        final count = refused + waiting;
        final chip = Tooltip(
          message: last == null
              ? 'สถานะการส่งข้อมูล'
              : 'ส่งล่าสุด ${syncTime(last, now)}',
          child: Material(
            key: const ValueKey('sync-status-btn'),
            color: stale ? t.dangerSoft : bg,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              onTap: () => showSyncStatusSheet(context, center),
              child: SizedBox(
                height: AppDimensions.tap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(icon, color: stale ? t.dangerInk : fg),
                      if (!compact || count > 0) ...[
                        const SizedBox(width: AppDimensions.space1),
                        Text(
                          compact ? '$count' : label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: stale ? t.dangerInk : fg,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        // Space before the user chip that follows in the header.
        return Padding(
          padding: const EdgeInsets.only(right: AppDimensions.space2),
          child: chip,
        );
      },
    );
  }
}

/// "⏳ รอส่ง" / "ส่งไม่ผ่าน" next to a bill that has not reached the server;
/// nothing for bills that did.
class BillSyncBadge extends StatelessWidget {
  const new({required this.billId, super.key});

  final String billId;

  @override
  Widget build(BuildContext context) {
    final center = SyncCenter.maybe;
    if (center == null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: center.entries,
      builder: (context, _, _) => switch (center.bills[billId]) {
        null => const SizedBox.shrink(),
        final s => Padding(
          padding: const EdgeInsets.only(left: AppDimensions.space1_5),
          child: InkWell(
            onTap: () => showSyncStatusSheet(context, center),
            child: Pill(
              key: ValueKey('bill-sync-$billId'),
              label: s == BillSync.refused ? 'ส่งไม่ผ่าน' : '⏳ รอส่ง',
              tone: s == BillSync.refused ? PillTone.red : PillTone.orange,
            ),
          ),
        ),
      },
    );
  }
}

/// Asks before [action] while data still waits to be sent. With [block] the
/// action is refused instead (e.g. leaving the shop would strand the data).
/// Returns whether to go ahead.
Future<bool> confirmWithPendingSync(
  BuildContext context, {
  required String action,
  bool block = false,
}) async {
  final center = SyncCenter.maybe;
  final n = center?.entries.value.length ?? 0;
  if (center == null || n == 0) return true;
  final go = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      key: const ValueKey('sync-guard-dialog'),
      title: Text(block ? 'ยัง$actionไม่ได้' : 'ยังมีข้อมูลรอส่ง $n รายการ'),
      content: Text(
        block
            ? 'มีข้อมูลรอส่ง $n รายการ ถ้า$actionตอนนี้ข้อมูลอาจหาย '
                  'ต่อเน็ตแล้วรอให้ส่งครบก่อน'
            : 'ข้อมูลยังอยู่ในเครื่องนี้ และจะส่งเองเมื่อเน็ตกลับมา '
                  'ต้องการ$actionต่อหรือไม่',
      ),
      actions: [
        TextButton(
          key: const ValueKey('sync-guard-view-btn'),
          onPressed: () {
            Navigator.pop(dialog, false);
            unawaited(showSyncStatusSheet(context, center));
          },
          child: const Text('ดูรายการ'),
        ),
        if (block)
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('ปิด'),
          )
        else ...[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            key: const ValueKey('sync-guard-continue-btn'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text('$actionต่อ'),
          ),
        ],
      ],
    ),
  );
  return go ?? false;
}
