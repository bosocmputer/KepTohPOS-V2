import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

/// Dining table status card (`function TableCard` in `prototype/index.html` &
/// `design/figma/table.png`).
/// Displays table name, seat/customer count, package, timer (`tableTimer`),
/// owing balance (`tableDue`), and status bar (`ว่าง` / `มีลูกค้า` / `เกินเวลา`
/// / `รอชำระ`).
class TableCard extends StatelessWidget {
  const new({
    required this.posState,
    required this.table,
    required this.onTap,
    super.key,
    this.openTable,
    this.now,
  });

  final PosState posState;
  final DiningTable table;
  final OpenTableState? openTable;
  final VoidCallback onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final o = openTable;

    if (o == null) {
      return Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(color: t.line),
        ),
        child: InkWell(
          key: ValueKey('table-card-${table.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AppIcon('table', size: AppDimensions.iconSm, color: t.ink),
                    const SizedBox(width: AppDimensions.space2),
                    Expanded(
                      child: Text(
                        table.name,
                        style: tt.titleLarge?.copyWith(color: t.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space1_5),
                Text(
                  '${table.seats} ที่นั่ง',
                  style: tt.bodySmall?.copyWith(color: t.muted),
                ),
                const SizedBox(height: AppDimensions.space3),
                Container(
                  height: AppDimensions.btnSmH,
                  decoration: BoxDecoration(
                    color: t.primary,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'ว่าง',
                    style: tt.bodySmall?.copyWith(
                      color: t.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    PackageItem? pkg;
    for (final p in posState.packages) {
      if (p.id == o.packageId) {
        pkg = p;
        break;
      }
    }
    final tm = tableTimer(posState, o, now: now);
    final due = tableDue(posState, o);
    final headCount = o.heads.a + o.heads.c + o.heads.f;
    final borderColor = tm.late ? t.danger : (due > 0 ? t.primary : t.line);

    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(
          color: borderColor,
          width: (tm.late || due > 0)
              ? AppDimensions.borderThick
              : AppDimensions.borderThin,
        ),
      ),
      child: InkWell(
        key: ValueKey('table-card-${table.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      AppIcon(
                        'table',
                        size: AppDimensions.iconSm,
                        color: t.ink,
                      ),
                      const SizedBox(width: AppDimensions.space2),
                      Text(
                        table.name,
                        style: tt.titleLarge?.copyWith(color: t.ink),
                      ),
                    ],
                  ),
                  Pill(
                    label: '$headCount คน',
                    tone: tm.late ? PillTone.red : PillTone.orange,
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space1_5),
              Text(
                '${pkg?.name ?? ""}'
                '${o.timing == "after" ? " · กินก่อนจ่าย" : ""}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: t.muted),
              ),
              const SizedBox(height: AppDimensions.space1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      tm.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        color: tm.late ? t.danger : t.muted,
                        fontWeight: tm.late ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (due > 0)
                    Text(
                      'รอชำระ ${baht(due)}',
                      style: tt.labelSmall?.copyWith(
                        color: t.primaryInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.space3),
              Container(
                height: AppDimensions.btnSmH,
                decoration: BoxDecoration(
                  color: tm.late
                      ? t.dangerSoft
                      : (due > 0 ? t.primarySoft : t.surface2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  tm.late ? 'มีลูกค้า · เกินเวลา' : 'มีลูกค้า',
                  style: tt.bodySmall?.copyWith(
                    color: tm.late
                        ? t.dangerInk
                        : (due > 0 ? t.primaryInk : t.muted),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact table switcher chip at the top of `SalePage` (`const TableChip` in
/// `prototype/index.html`).
class TableChip extends StatelessWidget {
  const new({
    required this.posState,
    required this.table,
    required this.active,
    required this.onTap,
    super.key,
    this.openTable,
    this.now,
  });

  final PosState posState;
  final DiningTable table;
  final OpenTableState? openTable;
  final bool active;
  final VoidCallback onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final o = openTable;
    final due = o != null ? tableDue(posState, o) : 0.0;
    final tm = o != null ? tableTimer(posState, o, now: now) : null;
    final sub = o != null ? '${o.heads.a + o.heads.c + o.heads.f} คน' : 'ใหม่';

    final borderColor = active
        ? t.primary
        : ((tm?.late ?? false) ? t.danger : (due > 0 ? t.primary : t.line));

    return Material(
      color: active ? t.primarySoft : t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        side: BorderSide(
          color: borderColor,
          width: active ? AppDimensions.borderBold : AppDimensions.borderThin,
        ),
      ),
      child: InkWell(
        key: ValueKey('table-chip-${table.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space3,
            vertical: AppDimensions.space1_5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                table.name,
                style: tt.bodyMedium?.copyWith(
                  color: active ? t.primaryInk : t.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppDimensions.space1_5),
              Text(
                sub,
                style: tt.labelSmall?.copyWith(
                  color: active ? t.primaryInk : t.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
