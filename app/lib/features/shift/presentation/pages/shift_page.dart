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
        final exactCount = state.history
            .where((h) => (h.counted ?? 0) - state.statsOf(h).expected == 0)
            .length;
        final diffCount = state.history.length - exactCount;

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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ยังไม่เปิดกะ',
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(color: tokens.ink),
                              ),
                              const Pill(label: 'ปิดอยู่'),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.space2),
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
                  PageHeader(
                    title: 'ประวัติกะ (14 กะล่าสุด)',
                    actions: [
                      if (state.history.isNotEmpty)
                        Pill(
                          tone: PillTone.green,
                          label:
                              'ยอดตรง $exactCount/${state.history.length} กะ',
                        ),
                      if (diffCount > 0)
                        Pill(
                          tone: PillTone.red,
                          label: 'มีส่วนต่าง $diffCount กะ',
                        ),
                    ],
                  ),
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
                      child: CloseShiftSummaryCard(state: state, stats: st),
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

  static String _cleanNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final bloc = context.read<ShiftBloc>();
    final openedDate = dkey(DateTime.parse(shift.openedAt).toLocal());
    final diff = state.diff;
    final totalSales = stats.cash + stats.qr + stats.transfer;

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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Wrap(
                spacing: AppDimensions.space2,
                runSpacing: AppDimensions.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Pill(
                    tone: PillTone.orange,
                    label: 'ยอดขายรวม ${baht(totalSales)} · ${stats.bills} บิล',
                  ),
                  const Pill(label: 'เปิดอยู่', tone: PillTone.green),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space4),
          ShiftStatsGrid(shift: shift, stats: stats),
          const SizedBox(height: AppDimensions.space4),
          Container(
            padding: const EdgeInsets.all(AppDimensions.space4),
            decoration: BoxDecoration(
              color: tokens.surface2,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: tokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'นับเงินสดจริงในลิ้นชัก (บาท)',
                  style: textTheme.labelMedium?.copyWith(
                    color: tokens.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.space2),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 680;
                    final diffPill = diff != null
                        ? Pill(
                            key: const ValueKey('shift-diff-pill'),
                            tone: diff == 0 ? PillTone.green : PillTone.red,
                            label: diff == 0
                                ? 'ยอดตรง'
                                : '${diff > 0 ? "เกิน " : "ขาด "}'
                                      '${baht(diff.abs(), 2)}',
                          )
                        : const Pill(label: 'รอระบุยอดนับจริง');
                    final closeBtn = Btn(
                      key: const ValueKey('close-shift-btn'),
                      label: 'ปิดกะ',
                      kind: BtnKind.dark,
                      disabled: state.countedValue == null,
                      onPressed: () =>
                          bloc.add(const ShiftConfirmCloseToggled(show: true)),
                    );
                    final controls = <Widget>[
                      SizedBox(
                        width: 240,
                        child: AppTextInput(
                          key: const ValueKey('shift-counted-input'),
                          value: fmtInputNum(state.countedInput),
                          placeholder: 'ระบุยอดที่นับได้',
                          suffixText: '฿',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (v) => bloc.add(
                            ShiftCountedInputChanged(v.replaceAll(',', '')),
                          ),
                        ),
                      ),
                      Btn(
                        key: const ValueKey('shift-fill-expected-btn'),
                        label: 'ตรงตามระบบ (${baht(stats.expected)})',
                        onPressed: () => bloc.add(
                          ShiftCountedInputChanged(_cleanNum(stats.expected)),
                        ),
                      ),
                      if (state.countedInput.isNotEmpty)
                        Btn(
                          key: const ValueKey('shift-clear-counted-btn'),
                          label: 'ล้างค่า',
                          icon: 'x',
                          kind: BtnKind.ghost,
                          onPressed: () =>
                              bloc.add(const ShiftCountedInputChanged('')),
                        ),
                      diffPill,
                    ];
                    if (!isWide) {
                      return Wrap(
                        spacing: AppDimensions.space3,
                        runSpacing: AppDimensions.space3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [...controls, closeBtn],
                      );
                    }
                    return Row(
                      children: [
                        for (var i = 0; i < controls.length; i++) ...[
                          if (i > 0)
                            const SizedBox(width: AppDimensions.space3),
                          controls[i],
                        ],
                        const Spacer(),
                        closeBtn,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
