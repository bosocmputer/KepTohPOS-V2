import 'dart:math' as math;

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

/// Daily profit/loss bar chart drawn with [CustomPainter] (`ProfitChart` in
/// `prototype/index.html:1512-1526`).
class ProfitChart extends StatelessWidget {
  const new({
    required this.days,
    super.key,
    this.showNetProfit = true,
    this.selectedDate,
    this.onSelectDate,
  });

  final List<LedgerDaySummary> days;
  final bool showNetProfit;
  final String? selectedDate;
  final ValueChanged<String>? onSelectDate;

  double? _valOf(LedgerDaySummary d) => showNetProfit ? d.netProfit : d.profit;

  LedgerDaySummary? get _selectedDay {
    if (selectedDate == null) return null;
    for (final d in days) {
      if (d.date == selectedDate) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final fieldName = showNetProfit ? 'กำไรสุทธิ' : 'กำไรขั้นต้น';
    final selected = _selectedDay;
    final selectedVal = selected != null ? _valOf(selected) : null;

    return Semantics(
      label: 'กราฟกำไรรายวัน',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Pill(
                  key: const ValueKey('profit-chart-selected-info'),
                  tone: !selected.closed || selectedVal == null
                      ? PillTone.neutral
                      : (selectedVal >= 0 ? PillTone.green : PillTone.red),
                  label: !selected.closed || selectedVal == null
                      ? '${thDateShort(selected.date)} '
                            '(${thDate(selected.date)}) · ยังไม่ปิดยอด'
                      : '${thDateShort(selected.date)} '
                            '(${thDate(selected.date)}) · '
                            '$fieldName ${baht(selectedVal)}',
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final minChartW = math.max<double>(days.length * 26.0, 260);
              final availW = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : minChartW;
              final chartW = math.max<double>(availW, math.min(minChartW, 520));
              const chartH = 200.0;
              const leftPad = 8.0;
              final bw = (chartW - leftPad * 2) / days.length;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartW,
                  height: chartH,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _ProfitChartPainter(
                              days: days,
                              showNetProfit: showNetProfit,
                              selectedDate: selectedDate,
                              tokens: tokens,
                              labelStyle:
                                  textTheme.labelSmall?.copyWith(
                                    color: tokens.muted,
                                    fontSize: 11,
                                  ) ??
                                  TextStyle(color: tokens.muted, fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < days.length; i++)
                        Positioned(
                          left: leftPad + i * bw,
                          top: 0,
                          width: bw,
                          height: chartH,
                          child: GestureDetector(
                            key: ValueKey('profit-chart-bar-${days[i].date}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onSelectDate != null
                                ? () => onSelectDate!(days[i].date)
                                : null,
                            child: const SizedBox.expand(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfitChartPainter extends CustomPainter {
  const new({
    required this.days,
    required this.showNetProfit,
    required this.selectedDate,
    required this.tokens,
    required this.labelStyle,
  });

  final List<LedgerDaySummary> days;
  final bool showNetProfit;
  final String? selectedDate;
  final AppTokens tokens;
  final TextStyle labelStyle;

  double? _valOf(LedgerDaySummary d) => showNetProfit ? d.netProfit : d.profit;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final w = size.width;
    final h = size.height;
    const top = 16.0;
    const bottom = 28.0;
    const left = 8.0;

    var maxVal = 1.0;
    var minVal = 0.0;
    for (final d in days) {
      final v = _valOf(d) ?? 0.0;
      if (v > maxVal) maxVal = v;
      if (v < minVal) minVal = v;
    }

    double yOf(double v) =>
        top + (maxVal - v) / (maxVal - minVal) * (h - top - bottom);

    final bw = (w - left * 2) / days.length;
    final axisPaint = Paint()
      ..color = tokens.line
      ..strokeWidth = 1;

    // 3 dashed grid lines + right-aligned numbers
    for (final k in const <int>[1, 2, 3]) {
      final v = maxVal * k / 3;
      final y = yOf(v);
      _drawDashedLine(canvas, Offset(0, y), Offset(w, y), axisPaint);
      final tp = TextPainter(
        text: TextSpan(text: fmt(v), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w - 4 - tp.width, y - tp.height - 2));
    }

    final posFill = Color.lerp(tokens.surface, tokens.success, 0.72)!;
    final yZero = yOf(0);

    // Bars
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final v = _valOf(d);
      final barX = left + i * bw + bw * 0.18;
      final barW = math.max<double>(2, bw * 0.64);
      final isSelected = d.date == selectedDate;

      if (!d.closed || v == null) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, yZero - 4, barW, 4),
          const Radius.circular(1),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = isSelected ? tokens.muted : tokens.line,
        );
      } else {
        final y0 = yOf(math.max(0, v));
        final hgt = math.max<double>(1, (yOf(v) - yZero).abs());
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, y0, barW, hgt),
          const Radius.circular(2),
        );
        final color = v >= 0
            ? (isSelected ? tokens.success : posFill)
            : tokens.danger;
        canvas.drawRRect(rect, Paint()..color = color);
        if (isSelected) {
          canvas.drawRRect(
            rect,
            Paint()
              ..color = tokens.ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }

    // Clear zero line
    canvas.drawLine(
      Offset(0, yZero),
      Offset(w, yZero),
      Paint()
        ..color = tokens.muted
        ..strokeWidth = 1,
    );

    // Date labels below axis (at most ~10 labels)
    final step = math.max(1, (days.length / 10).ceil());
    for (var i = 0; i < days.length; i++) {
      if (i % step == 0 || i == days.length - 1) {
        final dayNum = parseKey(days[i].date).day.toString();
        final tp = TextPainter(
          text: TextSpan(text: dayNum, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final cx = left + i * bw + bw / 2;
        tp.paint(canvas, Offset(cx - tp.width / 2, h - 8 - tp.height));
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashW = 3.0;
    const gapW = 3.0;
    var x = p1.dx;
    while (x < p2.dx) {
      final endX = math.min(x + dashW, p2.dx);
      canvas.drawLine(Offset(x, p1.dy), Offset(endX, p2.dy), paint);
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(covariant _ProfitChartPainter oldDelegate) =>
      oldDelegate.days != days ||
      oldDelegate.showNetProfit != showNetProfit ||
      oldDelegate.selectedDate != selectedDate ||
      oldDelegate.tokens != tokens;
}
