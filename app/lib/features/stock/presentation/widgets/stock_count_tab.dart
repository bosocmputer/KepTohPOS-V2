import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/bloc/stock_count_bloc.dart';
import 'package:app/features/stock/presentation/widgets/stock_count_numpad_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fast daily/weekly stock count tab (`StockCount` in `index.html:1352-1417`).
class StockCountTab extends StatefulWidget {
  const new({required this.staff, super.key});

  final StaffMember staff;

  @override
  State<StockCountTab> createState() => _StockCountTabState();
}

class _StockCountTabState extends State<StockCountTab> {
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String ingId) => _rowKeys.putIfAbsent(ingId, GlobalKey.new);

  void _scrollToActive(String? ingId) {
    if (ingId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _rowKeys[ingId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 120),
          alignment: 0.35,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final state = context.watch<StockCountBloc>().state;
    final bloc = context.read<StockCountBloc>();
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW <= AppDimensions.mobileBp;
    final curId = state.currentIngredientId;

    final listColumn = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? AppDimensions.space4 : AppDimensions.space6,
        AppDimensions.space4,
        isMobile ? AppDimensions.space4 : AppDimensions.space5,
        AppDimensions.space6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space4,
              vertical: AppDimensions.space2_5,
            ),
            decoration: BoxDecoration(
              color: state.isClosed ? t.primarySoft : t.surface,
              borderRadius: BorderRadius.circular(AppDimensions.r),
              border: Border.all(color: state.isClosed ? t.primary : t.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.isClosed
                        ? 'ปิดยอดแล้ว · แก้ตัวเลขแล้วกดบันทึกได้'
                        : 'แตะรายการแล้วป้อนจำนวนที่เหลือ · '
                              'Enter = รายการถัดไป',
                    style: tt.bodyMedium?.copyWith(
                      color: state.isClosed ? t.primaryInk : t.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  key: const ValueKey('stock-count-show-all'),
                  onTap: () => bloc.add(
                    StockCountShowAllToggled(showAll: !state.showAll),
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space2,
                      vertical: AppDimensions.space1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          state.showAll
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                          color: state.showAll ? t.primary : t.muted,
                        ),
                        const SizedBox(width: AppDimensions.space1_5),
                        Text(
                          'แสดงทุกรายการ',
                          style: tt.bodySmall?.copyWith(
                            color: t.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.skippedWeeklyCount > 0) ...[
            const SizedBox(height: AppDimensions.space2),
            Text(
              'ของนับรายสัปดาห์ '
              '(นับวัน${kDowNames[state.posState.shop.weeklyCountDow % 7]}) '
              '${state.skippedWeeklyCount} รายการ '
              'ระบบใช้ค่าประมาณจากอัตราใช้ต่อหัว',
              style: tt.bodySmall?.copyWith(color: t.muted),
            ),
          ],
          const SizedBox(height: AppDimensions.space4),
          for (final group in state.locationGroups) ...[
            Row(
              children: [
                Text(
                  kLocations[group.key] ?? group.key,
                  style: tt.titleMedium?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppDimensions.space2),
                Text(
                  '${group.value.length} รายการ',
                  style: tt.bodySmall?.copyWith(color: t.muted),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space2),
            _LocationCountTable(
              items: group.value,
              state: state,
              activeId: curId,
              keyOf: _keyFor,
              onSelectRow: (id) => bloc.add(StockCountItemSelected(id)),
            ),
            const SizedBox(height: AppDimensions.space4),
          ],
        ],
      ),
    );

    return BlocListener<StockCountBloc, StockCountState>(
      listenWhen: (prev, curr) =>
          prev.currentIngredientId != curr.currentIngredientId,
      listener: (context, s) => _scrollToActive(s.currentIngredientId),
      child: isMobile
          ? Column(
              children: [
                Expanded(child: listColumn),
                StockCountNumPadPanel(
                  state: state,
                  staff: widget.staff,
                  isMobile: true,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: listColumn),
                SizedBox(
                  width: AppDimensions.rightPanelWidth(screenW),
                  child: StockCountNumPadPanel(
                    state: state,
                    staff: widget.staff,
                    isMobile: false,
                  ),
                ),
              ],
            ),
    );
  }
}

class _LocationCountTable extends StatelessWidget {
  const new({
    required this.items,
    required this.state,
    required this.activeId,
    required this.keyOf,
    required this.onSelectRow,
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
      color: isActive ? t.primarySoft : t.surface,
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
                color: isActive ? t.primary : t.surface.withValues(alpha: 0),
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
                        'check',
                        key: ValueKey('count-checked-${ing.id}'),
                        size: AppDimensions.iconSm,
                        color: t.success,
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
                  isCounted ? val : '–',
                  key: ValueKey('count-val-${ing.id}'),
                  textAlign: TextAlign.right,
                  style: tt.bodyMedium?.copyWith(
                    color: isCounted ? t.ink : t.muted,
                    fontWeight: isCounted ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  calc.over
                      ? 'เกินที่มี'
                      : (usedVal != null
                            ? fmtQ(usedVal)
                            : ((dayRow?.est ?? false)
                                  ? '≈ ${fmtQ(dayRow?.used ?? 0)}'
                                  : '–')),
                  textAlign: TextAlign.right,
                  style: tt.bodyMedium?.copyWith(
                    color: calc.over
                        ? t.danger
                        : (usedVal != null ? t.ink : t.muted),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  costVal != null ? fmt(costVal) : '–',
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
