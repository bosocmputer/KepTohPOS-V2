import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/tables/presentation/widgets/table_live_timer.dart';
import 'package:flutter/material.dart';

/// Dining table status card (`function TableCard` in `prototype/index.html`).
class TableCard extends StatefulWidget {
  const new({
    required this.posState,
    required this.table,
    required this.onTap,
    super.key,
    this.openTable,
    this.now,
    this.onViewSlip,
  });
  final PosState posState;
  final DiningTable table;
  final OpenTableState? openTable;
  final VoidCallback onTap;
  final DateTime? now;
  final VoidCallback? onViewSlip;
  @override
  State<TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<TableCard> {
  bool _liveOvertime = false;
  @override
  void didUpdateWidget(covariant TableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openTable?.openedAt != widget.openTable?.openedAt ||
        oldWidget.openTable?.packageId != widget.openTable?.packageId) {
      _liveOvertime = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (t, tt) = (context.tokens, Theme.of(context).textTheme);
    final (posState, table, o) = (
      widget.posState,
      widget.table,
      widget.openTable,
    );
    final pkg = posState.packages
        .where((p) => p.id == o?.packageId)
        .firstOrNull;
    final tm = o == null ? null : tableTimer(posState, o, now: widget.now);
    final due = o == null ? 0.0 : tableDue(posState, o);
    final isLate = (tm?.late ?? false) || (o != null && _liveOvertime);
    final isAfterPaid =
        o != null && o.timing == 'after' && due == 0 && o.billIds.isNotEmpty;
    final (borderColor, statusBg, statusFg, statusTxt) = isLate
        ? (t.danger, t.dangerSoft, t.dangerInk, 'มีลูกค้า · เกินเวลา')
        : (due > 0
              ? (t.primary, t.primary, t.onPrimary, 'เช็กบิล ${baht(due)}')
              : (isAfterPaid
                    ? (
                        t.success,
                        t.successSoft,
                        t.successInk,
                        'ชำระแล้ว · เก็บโต๊ะ',
                      )
                    : (t.line, t.surface2, t.ink, 'มีลูกค้า')));
    final headTone = isLate
        ? PillTone.red
        : (o?.timing == 'after' ? PillTone.orange : PillTone.green);
    final timingTone = o?.timing == 'after' ? PillTone.orange : PillTone.green;
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(
          color: borderColor,
          width: (isLate || due > 0 || isAfterPaid)
              ? AppDimensions.borderThick
              : AppDimensions.borderThin,
        ),
      ),
      child: InkWell(
        key: ValueKey('table-card-${table.id}'),
        onTap: widget.onTap,
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
                  if (o == null)
                    const Pill(label: 'ว่าง')
                  else
                    Pill(
                      label: '${o.heads.a + o.heads.c + o.heads.f} คน',
                      tone: headTone,
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.space1_5),
              if (o == null) ...[
                Text(
                  '${table.seats} ที่นั่ง',
                  style: tt.bodySmall?.copyWith(color: t.muted),
                ),
                const SizedBox(height: AppDimensions.space3),
                Container(
                  height: AppDimensions.btnSmH,
                  decoration: BoxDecoration(
                    color: t.primarySoft.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(
                      color: t.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+ เปิดโต๊ะ',
                    style: tt.bodySmall?.copyWith(
                      color: t.primaryInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pkg?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(color: t.muted),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space1),
                    Pill(
                      label: o.timing == 'after'
                          ? 'กินก่อนจ่าย'
                          : 'จ่ายก่อนกิน',
                      tone: timingTone,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TableLiveTimer(
                        posState: posState,
                        tableId: table.id,
                        openTable: o,
                        fixedNow: widget.now,
                        onOvertimeReached: () =>
                            setState(() => _liveOvertime = true),
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
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: AppDimensions.btnSmH,
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSm,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          statusTxt,
                          style: tt.bodySmall?.copyWith(
                            color: statusFg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (due > 0 || isAfterPaid)
                      const SizedBox.shrink(child: Text('มีลูกค้า')),
                    if (widget.onViewSlip != null) ...[
                      const SizedBox(width: AppDimensions.space1_5),
                      Btn(
                        key: ValueKey('table-slip-btn-${table.id}'),
                        size: BtnSize.sm,
                        icon: 'receipt',
                        label: 'สลิป POS',
                        onPressed: widget.onViewSlip,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact table switcher chip at the top of `SalePage` (`const TableChip`).
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
    final (t, tt, o) = (context.tokens, Theme.of(context).textTheme, openTable);
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
