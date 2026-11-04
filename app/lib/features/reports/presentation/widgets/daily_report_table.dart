import 'dart:math' as math;

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/reports/presentation/pages/reports_page.dart'
    show ReportColSpec, buildReportColumns;
import 'package:flutter/material.dart';

/// Daily report table with a pinned left `วันที่` column and horizontally
/// scrollable metric columns (`ReportsView` in `prototype/index.html:1593-1612`).
class DailyReportTable extends StatelessWidget {
  const new({required this.report, super.key, this.onDayTap});

  final MonthlyReportSummary report;
  final ValueChanged<String>? onDayTap;

  static const double _pinnedColWidth = 200;
  static const double _rowHeight = 48;

  Widget _rightCell(double w, Widget child) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space2),
      child: Align(alignment: Alignment.centerRight, child: child),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final rows = report.reversedDays;
    if (rows.isEmpty) return const Empty(title: 'ไม่มีข้อมูลในเดือนนี้');
    final cols = buildReportColumns(report, t);
    final minRightW = cols.fold<double>(0, (a, c) => a + c.width);
    final headStyle = tt.labelSmall?.copyWith(
      color: t.muted,
      fontSize: AppDimensions.fsXs,
      fontWeight: FontWeight.w600,
    );
    final footBorder = Border(
      top: BorderSide(color: t.line, width: AppDimensions.borderThick),
    );
    final footTextStyle = TextStyle(
      color: t.ink,
      fontWeight: FontWeight.w700,
      fontSize: AppDimensions.fsSm,
    );

    return Semantics(
      label: 'รายงาน ${thMonth(report.selectedMonth)}',
      child: Container(
        key: const ValueKey('daily-report-table'),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppDimensions.r),
          border: Border.all(color: t.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availRight = math.max<double>(
              0,
              constraints.maxWidth - _pinnedColWidth,
            );
            final rightW = math.max<double>(availRight, minRightW);
            final scale = minRightW > 0 ? rightW / minRightW : 1.0;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: _pinnedColWidth,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: t.line)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: _rowHeight,
                        color: t.surface2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space3,
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text('วันที่', style: headStyle),
                      ),
                      for (var i = 0; i < rows.length; i++)
                        _buildPinnedDateCell(rows[i], i == rows.length - 1, t),
                      Container(
                        height: _rowHeight,
                        decoration: BoxDecoration(
                          color: t.surface2,
                          border: footBorder,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space3,
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text('รวม', style: footTextStyle),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('daily-report-horizontal-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: rightW,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: _rowHeight,
                            color: t.surface2,
                            child: Row(
                              children: [
                                for (final col in cols)
                                  _rightCell(
                                    col.width * scale,
                                    Text(col.label, style: headStyle),
                                  ),
                              ],
                            ),
                          ),
                          for (var i = 0; i < rows.length; i++)
                            _buildRightRow(
                              rows[i],
                              i == rows.length - 1,
                              cols,
                              scale,
                              t,
                            ),
                          Container(
                            height: _rowHeight,
                            decoration: BoxDecoration(
                              color: t.surface2,
                              border: footBorder,
                            ),
                            child: DefaultTextStyle.merge(
                              style: footTextStyle,
                              child: Row(
                                children: [
                                  for (final col in cols)
                                    _rightCell(
                                      col.width * scale,
                                      Text(col.foot),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPinnedDateCell(LedgerDaySummary d, bool isLast, AppTokens t) {
    final content = Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(color: t.line),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space3),
      child: Row(
        children: [
          Flexible(
            child: Text(
              thDate(d.date),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.ink, fontSize: AppDimensions.fsSm),
            ),
          ),
          if (!d.closed) ...[
            const SizedBox(width: AppDimensions.space1_5),
            const Pill(label: 'ยังไม่ปิด', tone: PillTone.orange),
          ],
        ],
      ),
    );
    if (onDayTap == null) return content;
    return Material(
      color: t.surface.withValues(alpha: 0),
      child: InkWell(
        key: ValueKey('report-row-${d.date}'),
        onTap: () => onDayTap!(d.date),
        child: content,
      ),
    );
  }

  Widget _buildRightRow(
    LedgerDaySummary d,
    bool isLast,
    List<ReportColSpec> cols,
    double scale,
    AppTokens t,
  ) {
    final content = Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(color: t.line),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: t.ink, fontSize: AppDimensions.fsSm),
        child: Row(
          children: [
            for (final col in cols) _rightCell(col.width * scale, col.cell(d)),
          ],
        ),
      ),
    );
    if (onDayTap == null) return content;
    return Material(
      color: t.surface.withValues(alpha: 0),
      child: InkWell(
        key: ValueKey('report-row-cells-${d.date}'),
        onTap: () => onDayTap!(d.date),
        child: content,
      ),
    );
  }
}
