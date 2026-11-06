import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:flutter/material.dart';

/// Responsive full-width stats grid for the active shift card.
class ShiftStatsGrid extends StatelessWidget {
  const new({required this.shift, required this.stats, super.key});

  final ShiftRecord shift;
  final ShiftStats stats;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final items = <({String label, String value, String sub, bool highlight})>[
      (
        label: 'เงินทอนตั้งต้น',
        value: baht(shift.floatAmount),
        sub: 'เงินสดเปิดกะ',
        highlight: false,
      ),
      (
        label: 'ขายเงินสด',
        value: baht(stats.cash),
        sub: 'รับเข้าลิ้นชัก',
        highlight: false,
      ),
      (
        label: 'QR พร้อมเพย์',
        value: baht(stats.qr),
        sub: 'เข้าบัญชีร้าน',
        highlight: false,
      ),
      (
        label: 'โอน/บัตร',
        value: baht(stats.transfer),
        sub: 'เข้าบัญชีร้าน',
        highlight: false,
      ),
      (
        label: 'เงินสดที่ควรมีในลิ้นชัก',
        value: baht(stats.expected),
        sub: '${stats.bills} บิล · เงินทอน + เงินสด',
        highlight: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return StatsGroup(
            children: [
              for (final item in items)
                Stat(label: item.label, value: item.value, sub: item.sub),
            ],
          );
        }
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: tokens.line),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: AppDimensions.borderThin,
                      color: tokens.line,
                    ),
                  Expanded(
                    flex: items[i].highlight ? 3 : 2,
                    child: ColoredBox(
                      color: items[i].highlight
                          ? tokens.primarySoft
                          : tokens.surface,
                      child: Stat(
                        label: items[i].label,
                        value: items[i].value,
                        sub: items[i].sub,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Summary card displayed inside the close-shift confirmation dialog.
class CloseShiftSummaryCard extends StatelessWidget {
  const new({required this.state, required this.stats, super.key});

  final ShiftState state;
  final ShiftStats stats;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final cnt = state.countedValue ?? 0;
    final diff = state.diff ?? 0;

    Widget row(String label, String val, {Color? valColor}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: tokens.muted),
          ),
          Text(
            val,
            style: textTheme.bodyMedium?.copyWith(
              color: valColor ?? tokens.ink,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space3_5),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('เงินสดที่ควรมีในลิ้นชัก', baht(stats.expected, 2)),
          row('เงินสดที่นับได้จริง', baht(cnt, 2)),
          row(
            'ส่วนต่าง',
            diff == 0
                ? 'ตรงตามระบบ (฿0.00)'
                : '${diff > 0 ? "เกิน " : "ขาด "}${baht(diff.abs(), 2)}',
            valColor: diff == 0 ? tokens.success : tokens.danger,
          ),
        ],
      ),
    );
  }
}

/// Warning banner shown on `ShiftPage` when eat-before-paying tables still owe.
class OwingTablesBanner extends StatelessWidget {
  const new({required this.state, required this.onGoTables, super.key});

  final ShiftState state;
  final VoidCallback onGoTables;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final names = state.owingTables.map((x) => x.name).join(', ');
    return Container(
      key: const ValueKey('shift-owing-banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space4,
        vertical: AppDimensions.space3_5,
      ),
      decoration: BoxDecoration(
        color: tokens.primarySoft,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: tokens.primarySoft2),
      ),
      child: Row(
        children: [
          AppIcon(
            'alert',
            size: AppDimensions.iconLg,
            color: tokens.primaryInk,
          ),
          const SizedBox(width: AppDimensions.space3),
          Expanded(
            child: Text(
              'มีโต๊ะค้างชำระ (กินก่อนจ่าย) $names รวม '
              '${baht(state.owedTotal)} · ปิดกะได้ '
              'แต่ยอดนี้จะยังไม่อยู่ในกะนี้',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.primaryInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space3),
          Btn(
            label: 'ไปหน้าโต๊ะ',
            kind: BtnKind.primary,
            size: BtnSize.sm,
            onPressed: onGoTables,
          ),
        ],
      ),
    );
  }
}

/// 14-shift history table (`DataTable` in `ShiftView` of `index.html`).
class ShiftHistoryTable extends StatelessWidget {
  const new({required this.state, super.key});

  final ShiftState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return PosDataTable<ShiftRecord>(
      label: 'ประวัติกะ',
      rows: state.history,
      empty: const Empty(title: 'ยังไม่มีประวัติกะ'),
      columns: [
        DataTableCol(
          key: 'd',
          label: 'วันที่ · เวลา',
          cellBuilder: (_, h) {
            final dateStr = thDate(dkey(DateTime.parse(h.openedAt).toLocal()));
            final openT = thTime(h.openedAt);
            final closeT = h.closedAt != null ? thTime(h.closedAt!) : '-';
            return Wrap(
              spacing: AppDimensions.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  dateStr,
                  style: textTheme.bodyMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$openT–$closeT',
                  style: textTheme.bodySmall?.copyWith(
                    color: tokens.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            );
          },
        ),
        DataTableCol(
          key: 'who',
          label: 'ผู้เปิดกะ',
          cellBuilder: (_, h) => Text(state.staffNameOf(h.staffId)),
        ),
        DataTableCol(
          key: 'bills',
          label: 'บิล',
          align: ColAlign.right,
          cellBuilder: (_, h) => Text('${state.statsOf(h).bills}'),
        ),
        DataTableCol(
          key: 'float',
          label: 'เงินทอน',
          align: ColAlign.right,
          cellBuilder: (_, h) =>
              Text(fmt(h.floatAmount), style: TextStyle(color: tokens.muted)),
        ),
        DataTableCol(
          key: 'cash',
          label: 'ขายเงินสด',
          align: ColAlign.right,
          cellBuilder: (_, h) => Text(fmt(state.statsOf(h).cash)),
        ),
        DataTableCol(
          key: 'qr',
          label: 'QR/โอน',
          align: ColAlign.right,
          cellBuilder: (_, h) {
            final st = state.statsOf(h);
            return Text(fmt(st.qr + st.transfer));
          },
        ),
        DataTableCol(
          key: 'exp',
          label: 'ควรมี',
          align: ColAlign.right,
          cellBuilder: (_, h) => Text(
            fmt(state.statsOf(h).expected),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataTableCol(
          key: 'cnt',
          label: 'นับได้',
          align: ColAlign.right,
          cellBuilder: (_, h) => Text(
            fmt(h.counted),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataTableCol(
          key: 'diff',
          label: 'ส่วนต่าง',
          align: ColAlign.right,
          cellBuilder: (_, h) {
            final d = (h.counted ?? 0) - state.statsOf(h).expected;
            final text = d == 0 ? 'ตรง' : '${d > 0 ? "+" : ""}${fmt(d)}';
            return Align(
              alignment: Alignment.centerRight,
              child: Pill(
                tone: d == 0 ? PillTone.green : PillTone.red,
                label: text,
              ),
            );
          },
        ),
      ],
    );
  }
}
