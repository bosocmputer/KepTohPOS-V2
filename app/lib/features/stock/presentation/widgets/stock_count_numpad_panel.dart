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
    final prev = curIng != null ? state.prevCountOf(curIng.id) : null;
    final curVal = state.currentValue;
    final showPad = !isMobile || state.padOpen;
    final canReopen = staff.role != 'cashier';

    final prevText = prev != null ? ' · ครั้งก่อน ${fmtQ(prev)}' : '';
    final enteredText = curVal.isNotEmpty
        ? 'ใส่แล้ว $curVal ${curIng?.unit ?? ""}'
        : 'แตะตัวเลขเพื่อใส่จำนวน';

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kLocations[curIng.location] ?? '',
                            style: tt.labelSmall?.copyWith(
                              color: t.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            curIng.name,
                            key: const ValueKey('stock-count-active-name'),
                            style: tt.titleLarge?.copyWith(
                              color: t.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'มีทั้งหมด ${fmtQ(curRow?.avail ?? 0)} '
                            '${curIng.unit}$prevText',
                            style: tt.bodySmall?.copyWith(color: t.muted),
                          ),
                          Text(
                            key: const ValueKey('stock-count-progress'),
                            '$enteredText · นับแล้ว '
                            '${state.doneDueCount}/'
                            '${state.dueIngredients.length}',
                            style: tt.labelSmall?.copyWith(
                              color: t.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          key: const ValueKey('stock-count-display-val'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.space3,
                            vertical: AppDimensions.space1_5,
                          ),
                          decoration: BoxDecoration(
                            color: t.surface2,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSm,
                            ),
                            border: Border.all(color: t.line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                curVal.isEmpty ? '0' : curVal,
                                style: tt.displayMedium?.copyWith(
                                  color: curVal.isEmpty ? t.muted : t.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.space1),
                              Text(
                                curIng.unit,
                                style: tt.bodySmall?.copyWith(color: t.muted),
                              ),
                            ],
                          ),
                        ),
                        if (isMobile) ...[
                          const SizedBox(width: AppDimensions.space2),
                          Btn(
                            key: const ValueKey('stock-count-pad-toggle'),
                            size: BtnSize.sm,
                            label: state.padOpen ? 'ย่อ' : 'ป้อน',
                            onPressed: () =>
                                bloc.add(const StockCountPadToggled()),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (showPad) ...[
                  const SizedBox(height: AppDimensions.space3),
                  Center(
                    child: NumPad(
                      key: ValueKey('stock-count-numpad-${curIng.id}'),
                      value: curVal,
                      decimal: !isDiscreteUnit(curIng.unit),
                      maxDecimalPlaces: 1,
                      maxLen: 7,
                      keyboard: true,
                      keyHeight: AppDimensions.numPadKeyCompactH,
                      onChanged: (v) => bloc.add(StockCountValueChanged(v)),
                      onEnter: (_) => bloc.add(const StockCountNextPressed()),
                    ),
                  ),
                ],
                if (!isMobile) const Spacer(),
                const SizedBox(height: AppDimensions.space3),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.space3),
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
                            '${state.doneDueCount}/'
                            '${state.dueIngredients.length}',
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.space1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ต้นทุนจากที่นับ', style: tt.bodySmall),
                          Text(
                            baht(state.totalCountedCost),
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (state.hasDraft) ...[
                        const SizedBox(height: AppDimensions.space2),
                        Btn(
                          key: const ValueKey('stock-count-cancel-draft-btn'),
                          kind: BtnKind.ghost,
                          size: BtnSize.sm,
                          block: true,
                          label: 'ยกเลิกที่แก้',
                          onPressed: () =>
                              bloc.add(const StockCountDraftCancelled()),
                        ),
                      ],
                      if (state.isClosed && !state.hasDraft && canReopen) ...[
                        const SizedBox(height: AppDimensions.space2),
                        Btn(
                          key: const ValueKey('stock-count-reopen-btn'),
                          kind: BtnKind.ghost,
                          size: BtnSize.sm,
                          block: true,
                          label: 'ยกเลิกการปิดวัน',
                          onPressed: () =>
                              bloc.add(StockCountDayReopened(staff: staff)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space3),
                Btn(
                  key: const ValueKey('stock-count-next-btn'),
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
