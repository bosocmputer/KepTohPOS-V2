import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/bloc/stock_count_bloc.dart';
import 'package:flutter/material.dart';

/// Per-location table of ingredients in `StockCountTab`.
class LocationCountTable extends StatelessWidget {
  const new({
    required this.items,
    required this.state,
    required this.activeId,
    required this.keyOf,
    required this.onSelectRow,
    super.key,
  });

  final List<IngredientItem> items;
  final StockCountState state;
  final String? activeId;
  final GlobalKey Function(String ingId) keyOf;
  final ValueChanged<String> onSelectRow;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final vals = state.values;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.r),
        border: Border.all(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space4,
              vertical: AppDimensions.space2_5,
            ),
            decoration: BoxDecoration(
              color: t.surface2,
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text('วัตถุดิบ', style: tt.labelMedium),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'มีทั้งหมด',
                    textAlign: TextAlign.right,
                    style: tt.labelMedium,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'เหลือจริง',
                    textAlign: TextAlign.right,
                    style: tt.labelMedium,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ใช้ไป',
                    textAlign: TextAlign.right,
                    style: tt.labelMedium,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'มูลค่า',
                    textAlign: TextAlign.right,
                    style: tt.labelMedium,
                  ),
                ),
              ],
            ),
          ),
          for (var idx = 0; idx < items.length; idx++)
            _buildRow(context, items[idx], idx == items.length - 1, vals),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    IngredientItem ing,
    bool isLast,
    Map<String, String> vals,
  ) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final isActive = ing.id == activeId;
    final val = vals[ing.id] ?? '';
    final isCounted = val.trim().isNotEmpty;
    final prev = state.prevCountOf(ing.id);
    final dayRow = state.rowOf(ing.id);
    final calc = state.calcOf(ing);
    final usedVal = calc.used;
    final costVal = calc.cost;

    final prevText = prev != null ? ' · ครั้งก่อน ${fmtQ(prev)}' : '';
    final weeklyText = ing.countFreq == 'weekly' ? ' · นับรายสัปดาห์' : '';

    return Material(
      key: keyOf(ing.id),
      color: calc.over
          ? t.dangerSoft.withValues(alpha: isActive ? 0.85 : 0.45)
          : (isActive ? t.primarySoft : t.surface),
      child: InkWell(
        key: ValueKey('count-row-${ing.id}'),
        onTap: () => onSelectRow(ing.id),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space4,
            vertical: AppDimensions.space3,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: calc.over
                    ? t.danger
                    : (isActive ? t.primary : t.surface.withValues(alpha: 0)),
                width: AppDimensions.borderAccent,
              ),
              bottom: isLast ? BorderSide.none : BorderSide(color: t.line),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    if (isCounted) ...[
                      AppIcon(
                        calc.over ? 'alert' : 'check',
                        key: ValueKey('count-checked-${ing.id}'),
                        size: AppDimensions.iconSm,
                        color: calc.over ? t.danger : t.success,
                      ),
                      const SizedBox(width: AppDimensions.space1_5),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ing.name,
                            style: tt.bodyMedium?.copyWith(
                              color: t.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${ing.unit}$prevText$weeklyText',
                            style: tt.labelSmall?.copyWith(color: t.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  fmtQ(dayRow?.avail ?? 0),
                  textAlign: TextAlign.right,
                  style: tt.bodyMedium?.copyWith(color: t.ink),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  isCounted ? fmtInputNum(val) : '–',
                  key: ValueKey('count-val-${ing.id}'),
                  textAlign: TextAlign.right,
                  style: tt.bodyMedium?.copyWith(
                    color: calc.over ? t.danger : (isCounted ? t.ink : t.muted),
                    fontWeight: isCounted ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: calc.over
                    ? const Align(
                        alignment: Alignment.centerRight,
                        child: Pill(tone: PillTone.red, label: 'เกินที่มี'),
                      )
                    : Text(
                        usedVal != null
                            ? fmtQ(usedVal)
                            : ((dayRow?.est ?? false)
                                  ? '≈ ${fmtQ(dayRow?.used ?? 0)}'
                                  : '–'),
                        textAlign: TextAlign.right,
                        style: tt.bodyMedium?.copyWith(
                          color: usedVal != null ? t.ink : t.muted,
                        ),
                      ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  costVal != null ? fmtBaht(costVal) : '–',
                  textAlign: TextAlign.right,
                  style: tt.bodyMedium?.copyWith(
                    color: costVal != null ? t.ink : t.muted,
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
