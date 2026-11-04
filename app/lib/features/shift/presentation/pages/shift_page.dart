import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:app/features/shift/presentation/widgets/open_shift_form.dart';
import 'package:app/features/shift/presentation/widgets/shift_history_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/shift/presentation/widgets/open_shift_form.dart';
export 'package:app/features/shift/presentation/widgets/shift_history_table.dart';

/// Cashier shift management screen (`ShiftView` in `prototype/index.html`).
class ShiftPage extends StatelessWidget {
  const new({
    required this.staffId,
    required this.staffName,
    super.key,
    this.onGoTables,
  });

  final String staffId;
  final String staffName;
  final VoidCallback? onGoTables;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return BlocBuilder<ShiftBloc, ShiftState>(
      builder: (context, state) {
        final bloc = context.read<ShiftBloc>();
        final shift = state.activeShift;
        final st = state.activeStats;

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.space6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (shift != null && st != null)
                    _ActiveShiftCard(shift: shift, stats: st, state: state)
                  else
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.space5),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.r),
                        border: Border.all(color: tokens.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ยังไม่เปิดกะ',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(color: tokens.ink),
                          ),
                          const SizedBox(height: AppDimensions.space3),
                          OpenShiftForm(staffId: staffId, staffName: staffName),
                        ],
                      ),
                    ),
                  if (shift != null && state.owingTables.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.space4),
                    OwingTablesBanner(
                      state: state,
                      onGoTables: onGoTables ?? () {},
                    ),
                  ],
                  const SizedBox(height: AppDimensions.space5),
                  const PageHeader(title: 'ประวัติกะ (14 กะล่าสุด)'),
                  const SizedBox(height: AppDimensions.space3),
                  ShiftHistoryTable(state: state),
                ],
              ),
            ),
            if (state.confirmClose && shift != null && st != null)
              ColoredBox(
                color: tokens.scrim,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.space4),
                    child: Confirm(
                      title: 'ปิดกะ?',
                      text: _confirmCloseText(state),
                      yesLabel: 'ปิดกะ',
                      onNo: () =>
                          bloc.add(const ShiftConfirmCloseToggled(show: false)),
                      onYes: () => bloc.add(ShiftClosed(staffId: staffId)),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _confirmCloseText(ShiftState state) {
    final cnt = state.countedValue ?? 0;
    final diff = state.diff ?? 0;
    final diffPart = diff == 0 ? ' · ยอดตรง' : ' · ส่วนต่าง ${baht(diff, 2)}';
    final owingPart = state.owingTables.isNotEmpty
        ? ' · มีโต๊ะค้างชำระ ${state.owingTables.length} โต๊ะ '
              '(${baht(state.owedTotal)})'
        : '';
    return 'นับได้ ${baht(cnt, 2)}$diffPart$owingPart';
  }
}

class _ActiveShiftCard extends StatelessWidget {
  const new({required this.shift, required this.stats, required this.state});

  final ShiftRecord shift;
  final ShiftStats stats;
  final ShiftState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final bloc = context.read<ShiftBloc>();
    final openedDate = dkey(DateTime.parse(shift.openedAt).toLocal());
    final diff = state.diff;

    return Container(
      key: const ValueKey('active-shift-card'),
      padding: const EdgeInsets.all(AppDimensions.space5),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppDimensions.r),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'กะปัจจุบัน · ${state.staffNameOf(shift.staffId)}',
                      style: textTheme.displaySmall?.copyWith(
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space1),
                    Text(
                      'เปิดเมื่อ ${thDate(openedDate)} '
                      '${thTime(shift.openedAt)}',
                      style: textTheme.bodySmall?.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
              ),
              const Pill(label: 'เปิดอยู่', tone: PillTone.green),
            ],
          ),
          const SizedBox(height: AppDimensions.space4),
          StatsGroup(
            children: [
              Stat(label: 'เงินทอนตั้งต้น', value: baht(shift.floatAmount)),
              Stat(label: 'ขายเงินสด', value: baht(stats.cash)),
              Stat(label: 'QR พร้อมเพย์', value: baht(stats.qr)),
              Stat(label: 'โอน/บัตร', value: baht(stats.transfer)),
              Stat(
                label: 'เงินสดที่ควรมีในลิ้นชัก',
                value: baht(stats.expected),
                sub: '${stats.bills} บิล',
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space4),
          Wrap(
            spacing: AppDimensions.space3,
            runSpacing: AppDimensions.space3,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 260,
                child: Field(
                  label: 'นับเงินสดจริงในลิ้นชัก (บาท)',
                  child: AppTextInput(
                    key: const ValueKey('shift-counted-input'),
                    value: state.countedInput,
                    placeholder: 'ระบุยอดที่นับได้',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => bloc.add(ShiftCountedInputChanged(v)),
                  ),
                ),
              ),
              if (diff != null)
                Pill(
                  key: const ValueKey('shift-diff-pill'),
                  tone: diff == 0 ? PillTone.green : PillTone.red,
                  label: diff == 0
                      ? 'ยอดตรง'
                      : '${diff > 0 ? "เกิน " : "ขาด "}${baht(diff.abs(), 2)}',
                ),
              Btn(
                key: const ValueKey('close-shift-btn'),
                label: 'ปิดกะ',
                kind: BtnKind.dark,
                disabled: state.countedValue == null,
                onPressed: () =>
                    bloc.add(const ShiftConfirmCloseToggled(show: true)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
