import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/sync/sync_center.dart';
import 'package:app/core/sync/sync_describe.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Opens "สถานะการส่งข้อมูล": what still waits, what was refused and why,
/// with buttons to send now and to retry refused items.
Future<void> showSyncStatusSheet(BuildContext context, SyncCenter center) =>
    showDialog<void>(
      context: context,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: SyncStatusSheet(center: center),
      ),
    );

class SyncStatusSheet extends StatelessWidget {
  const new({required this.center, super.key, this.now});

  final SyncCenter center;

  /// Fixed clock for tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(<Listenable>[
      center.entries,
      center.status,
      center.lastSynced,
    ]),
    builder: (context, _) {
      final t = context.tokens;
      final tt = Theme.of(context).textTheme;
      final at = (now ?? DateTime.now)();
      final s = center.status.value;
      final all = center.entries.value;
      final waiting = all.where((e) => !e.rejected).toList();
      final refused = all.where((e) => e.rejected).toList();
      final last = center.lastSynced.value;
      final busy = s.progress != null && !s.progress!.done;
      final head = <String>[
        if (s.online) 'ออนไลน์' else 'ออฟไลน์ · ขายต่อได้',
        if (last != null) 'ส่งล่าสุด ${syncTime(last, at)}',
      ].join(' · ');

      Widget section(
        String title,
        List<OutboxEntry> rows, {
        bool bad = false,
      }) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppDimensions.space3),
          Text(
            title,
            style: tt.titleSmall?.copyWith(color: bad ? t.dangerInk : t.ink),
          ),
          for (final e in rows) _Row(entry: e, center: center, at: at),
        ],
      );

      return Modal(
        key: const ValueKey('sync-status-sheet'),
        title: 'สถานะการส่งข้อมูล',
        sub: head,
        onClose: () => Navigator.pop(context),
        footer: [
          if (refused.isNotEmpty)
            Btn(
              key: const ValueKey('sync-retry-btn'),
              label: 'ส่งใหม่ (${refused.length})',
              icon: 'alert',
              disabled: busy,
              onPressed: center.retryRefused,
            ),
          Btn(
            key: const ValueKey('sync-send-now-btn'),
            label: busy ? 'กำลังส่ง…' : 'ส่งตอนนี้',
            kind: BtnKind.primary,
            loading: busy,
            disabled: waiting.isEmpty,
            onPressed: center.sendNow,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (center.isStale(at))
              Container(
                key: const ValueKey('sync-stale-warning'),
                padding: const EdgeInsets.all(AppDimensions.space2),
                decoration: BoxDecoration(
                  color: t.dangerSoft,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  'มีข้อมูลค้างส่งเกิน 3 วัน · '
                  'ต่อเน็ตเพื่อส่งข้อมูลก่อนครบ 7 วัน '
                  'ไม่อย่างนั้นระบบอาจไม่รับรายการที่ค้าง',
                  style: tt.bodyMedium?.copyWith(
                    color: t.dangerInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.space4,
                ),
                child: Text(
                  'ส่งครบแล้ว ไม่มีรายการค้าง',
                  key: const ValueKey('sync-all-sent'),
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge?.copyWith(color: t.success),
                ),
              ),
            if (refused.isNotEmpty)
              section(
                'ส่งไม่ผ่าน ${refused.length} รายการ',
                refused,
                bad: true,
              ),
            if (waiting.isNotEmpty)
              section('รอส่ง ${waiting.length} รายการ', waiting),
          ],
        ),
      );
    },
  );
}

class _Row extends StatelessWidget {
  const new({required this.entry, required this.center, required this.at});

  final OutboxEntry entry;
  final SyncCenter center;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final why = entry.rejected ? refusalReason(entry.lastError) : null;
    return Padding(
      key: ValueKey('sync-entry-${entry.id}'),
      padding: const EdgeInsets.only(top: AppDimensions.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            describeEntry(entry, center.shop, at),
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (why != null) ...[
            Text(
              'สาเหตุ: ${why.$1}',
              style: tt.bodySmall?.copyWith(color: t.dangerInk),
            ),
            Text(
              'ทำอย่างไร: ${why.$2}',
              style: tt.bodySmall?.copyWith(color: t.muted),
            ),
          ],
        ],
      ),
    );
  }
}
