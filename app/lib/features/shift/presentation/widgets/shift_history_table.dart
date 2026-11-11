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
    ({String label, String value, String sub, bool highlight}) it(
      String l,
      int v,
      String s, {
      bool h = false,
    }) => (label: l, value: baht(v), sub: s, highlight: h);
    final items = [
      it('เงินทอนตั้งต้น', shift.floatAmount, 'เงินสดเปิดกะ'),
      it('ขายเงินสด', stats.cash, 'รับเข้าลิ้นชัก'),
      it('QR พร้อมเพย์', stats.qr, 'เข้าบัญชีร้าน'),
      it('โอน/บัตร', stats.transfer, 'เข้าบัญชีร้าน'),
      it(
        'เงินสดที่ควรมีในลิ้นชัก',
        stats.expected,
        '${stats.bills} บิล · เงินทอน + เงินสด',
        h: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 720
          ? StatsGroup(
              children: [
                for (final item in items)
                  Stat(label: item.label, value: item.value, sub: item.sub),
              ],
            )
          : Container(
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
            ),
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
    final allNames = state.openTablesList.map((x) => x.name).join(', ');
    final bannerText = state.owingTables.isNotEmpty
        ? 'ยังมีโต๊ะเปิดอยู่ ${state.openTablesList.length} โต๊ะ '
              '($allNames · ค้างชำระ ${baht(state.owedTotal)}) · '
              'กรุณาเช็กบิลและเก็บโต๊ะให้ครบก่อนปิดกะ'
        : 'ยังมีโต๊ะที่ยังไม่ได้เก็บโต๊ะ '
              '${state.openTablesList.length} โต๊ะ ($allNames) · '
              'กรุณาเก็บโต๊ะให้ครบก่อนปิดกะ';
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
              bannerText,
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

  DataTableCol<ShiftRecord> _numCol(
    String k,
    String l,
    Widget Function(ShiftRecord) fn,
  ) => DataTableCol(
    key: k,
    label: l,
    align: ColAlign.right,
    cellBuilder: (_, h) => fn(h),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    const bold = TextStyle(fontWeight: FontWeight.w600);
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
              spacing: 8,
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
        _numCol('bills', 'บิล', (h) => Text('${state.statsOf(h).bills}')),
        _numCol(
          'float',
          'เงินทอน',
          (h) => Text(
            fmtBaht(h.floatAmount),
            style: TextStyle(color: tokens.muted),
          ),
        ),
        _numCol(
          'cash',
          'ขายเงินสด',
          (h) => Text(fmtBaht(state.statsOf(h).cash)),
        ),
        _numCol('qr', 'QR/โอน', (h) {
          final st = state.statsOf(h);
          return Text(fmtBaht(st.qr + st.transfer));
        }),
        _numCol(
          'exp',
          'ควรมี',
          (h) => Text(fmtBaht(state.statsOf(h).expected), style: bold),
        ),
        _numCol('cnt', 'นับได้', (h) => Text(fmtBaht(h.counted), style: bold)),
        _numCol('diff', 'ส่วนต่าง', (h) {
          final d = (h.counted ?? 0) - state.statsOf(h).expected;
          final text = d == 0 ? 'ตรง' : '${d > 0 ? "+" : ""}${fmtBaht(d)}';
          return Align(
            alignment: Alignment.centerRight,
            child: Pill(
              tone: d == 0 ? PillTone.green : PillTone.red,
              label: text,
            ),
          );
        }),
      ],
    );
  }
}
