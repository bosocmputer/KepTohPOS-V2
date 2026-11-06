import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/bloc/stock_count_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fixed right-hand (iPad landscape) or collapsible bottom (mobile) numpad
/// panel for `StockCountTab` (`count-pad` in `prototype/index.html:1399-1416`).
class StockCountNumPadPanel extends StatelessWidget {
  const new({
    required this.state,
    required this.staff,
    required this.isMobile,
    super.key,
  });

  final StockCountState state;
  final StaffMember staff;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final bloc = context.read<StockCountBloc>();
    final curIng = state.currentIngredient;
    final curRow = curIng != null ? state.rowOf(curIng.id) : null;
    final curCalc = curIng != null ? state.calcOf(curIng) : null;
    final isCurOver = curCalc?.over ?? false;
    final overCount = state.dueIngredients
        .where((i) => state.calcOf(i).over)
        .length;
    final prev = curIng != null ? state.prevCountOf(curIng.id) : null;
    final curVal = state.currentValue;
    final showPad = !isMobile || state.padOpen;
    final canReopen = staff.role != 'cashier';

    final prevText = prev != null ? ' · ครั้งก่อน ${fmtQ(prev)}' : '';
    final fmtCurVal = fmtInputNum(curVal);
    final enteredText = curVal.isNotEmpty
        ? 'ใส่แล้ว $fmtCurVal ${curIng?.unit ?? ""}'
        : 'แตะตัวเลขเพื่อใส่จำนวน';
    final availText = fmtQ(curRow?.avail ?? 0);
    final dueCountText = '${state.doneDueCount}/${state.dueIngredients.length}';
    final progressText = isCurOver
        ? 'เกินที่มีอยู่ (สูงสุด $availText ${curIng?.unit ?? ""}) · '
              'นับแล้ว $dueCountText'
        : '$enteredText · นับแล้ว $dueCountText';

    return Container(
      key: const ValueKey('stock-count-pad'),
      padding: const EdgeInsets.all(AppDimensions.space4),
      decoration: BoxDecoration(
        color: t.surface,
        border: isMobile
            ? Border(top: BorderSide(color: t.line))
            : Border(left: BorderSide(color: t.line)),
      ),
      child: curIng == null
          ? const Empty(title: 'ไม่มีรายการให้นับวันนี้')
          : Column(
              mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      kLocations[curIng.location] ?? '',
                      style: tt.labelSmall?.copyWith(
                        color: t.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space2),
                    Expanded(
                      child: Text(
                        curIng.name,
                        key: const ValueKey('stock-count-active-name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleLarge?.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isMobile)
                      Btn(
                        key: const ValueKey('stock-count-pad-toggle'),
                        size: BtnSize.sm,
                        label: state.padOpen ? 'ย่อ' : 'ป้อน',
                        onPressed: () => bloc.add(const StockCountPadToggled()),
                      ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceHalf),
                Text(
                  'มีทั้งหมด $availText ${curIng.unit}$prevText',
                  style: tt.bodySmall?.copyWith(color: t.muted),
                ),
                const SizedBox(height: AppDimensions.spaceHalf),
                Text(
                  key: const ValueKey('stock-count-progress'),
                  progressText,
                  style: tt.labelSmall?.copyWith(
                    color: isCurOver ? t.danger : t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimensions.space2),
                Container(
                  key: const ValueKey('stock-count-display-val'),
                  height: 46,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space3,
                  ),
                  decoration: BoxDecoration(
                    color: isCurOver ? t.dangerSoft : t.surface2,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: isCurOver ? t.danger : t.line),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isCurOver ? 'เกินจำนวนที่มี!' : 'เหลือจริง',
                        style: tt.labelMedium?.copyWith(
                          color: isCurOver ? t.danger : t.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space2),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              curVal.isEmpty ? '0' : fmtCurVal,
                              style: tt.displayMedium?.copyWith(
                                color: isCurOver
                                    ? t.danger
                                    : (curVal.isEmpty ? t.muted : t.ink),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space1_5),
                      Text(
                        curIng.unit,
                        style: tt.bodySmall?.copyWith(
                          color: isCurOver ? t.danger : t.muted,
                        ),
                      ),
                      if (curVal.isNotEmpty) ...[
                        const SizedBox(width: AppDimensions.space2),
                        GestureDetector(
                          key: const ValueKey('stock-count-clear-val-btn'),
                          onTap: () =>
                              bloc.add(const StockCountValueChanged('')),
                          child: AppIcon(
                            'x',
                            size: AppDimensions.iconSm,
                            color: isCurOver ? t.danger : t.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showPad) ...[
                  const SizedBox(height: AppDimensions.space2),
                  Center(
                    child: NumPad(
                      key: ValueKey('stock-count-numpad-${curIng.id}'),
                      value: curVal,
                      decimal: !isDiscreteUnit(curIng.unit),
                      maxDecimalPlaces: 1,
                      maxLen: 7,
                      filledKeys: true,
                      showClear: true,
                      maxWidth: double.infinity,
                      keyboard: true,
                      keyHeight: 46,
                      rowGap: AppDimensions.space1_5,
                      onChanged: (v) => bloc.add(StockCountValueChanged(v)),
                      onEnter: (_) => bloc.add(const StockCountNextPressed()),
                    ),
                  ),
                ],
                if (!isMobile) const Spacer(),
                const SizedBox(height: AppDimensions.space2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space3,
                    vertical: AppDimensions.space2_5,
                  ),
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('นับแล้ว', style: tt.bodySmall),
                          Text(
                            overCount > 0
                                ? '$dueCountText · เกินที่มี $overCount รายการ'
                                : dueCountText,
                            style: tt.bodyMedium?.copyWith(
                              color: overCount > 0 ? t.danger : t.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.space1),
                      Row(
                        children: [
                          Text('ต้นทุนจากที่นับ', style: tt.bodySmall),
                          if (state.hasDraft || (state.isClosed && canReopen))
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppDimensions.space2,
                              ),
                              child: GestureDetector(
                                key: ValueKey(
                                  state.hasDraft
                                      ? 'stock-count-cancel-draft-btn'
                                      : 'stock-count-reopen-btn',
                                ),
                                onTap: () => bloc.add(
                                  state.hasDraft
                                      ? const StockCountDraftCancelled()
                                      : StockCountDayReopened(staff: staff),
                                ),
                                child: Text(
                                  state.hasDraft
                                      ? 'ยกเลิกที่แก้'
                                      : 'ยกเลิกการปิดวัน',
                                  style: tt.labelSmall?.copyWith(
                                    color: t.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            baht(state.totalCountedCost),
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space2),
                Btn(
                  key: const ValueKey('stock-count-next-btn'),
                  kind: BtnKind.dark,
                  block: true,
                  label: 'รายการถัดไป',
                  onPressed: () => bloc.add(const StockCountNextPressed()),
                ),
                const SizedBox(height: AppDimensions.space2),
                Btn(
                  key: const ValueKey('stock-count-save-btn'),
                  kind: BtnKind.primary,
                  size: BtnSize.lg,
                  block: true,
                  icon: 'check',
                  label: 'บันทึกและปิดวัน',
                  disabled: !state.canSave,
                  onPressed: () => bloc.add(const StockCountSaved()),
                ),
              ],
            ),
    );
  }
}
