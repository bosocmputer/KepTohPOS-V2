import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Quick preset float amounts for opening a shift.
const List<int> _kFloatPresets = <int>[1000, 2000, 3000, 5000];

/// Form for opening a new cashier shift (`OpenShiftForm` in
/// `prototype/index.html`).
class OpenShiftForm extends StatelessWidget {
  const new({
    required this.staffId,
    required this.staffName,
    super.key,
    this.onDone,
  });

  final String staffId;
  final String staffName;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<ShiftBloc, ShiftState>(
      builder: (context, state) {
        final bloc = context.read<ShiftBloc>();
        final currentVal = double.tryParse(
          state.floatInput.replaceAll(',', '').trim(),
        );

        Widget buildInput() => Field(
          label: 'เงินทอนตั้งต้นในลิ้นชัก (บาท)',
          child: AppTextInput(
            key: const ValueKey('shift-float-input'),
            value: fmtInputNum(state.floatInput),
            placeholder: 'ระบุเงินทอนตั้งต้น',
            suffixText: '฿',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) =>
                bloc.add(ShiftFloatInputChanged(v.replaceAll(',', ''))),
          ),
        );

        Widget buildPresetRow() => Wrap(
          spacing: AppDimensions.space2,
          runSpacing: AppDimensions.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final preset in _kFloatPresets)
              Btn(
                key: ValueKey('shift-float-preset-$preset'),
                label: '฿${fmt(preset)}',
                size: BtnSize.sm,
                kind: currentVal == preset.toDouble()
                    ? BtnKind.dark
                    : BtnKind.normal,
                onPressed: () =>
                    bloc.add(ShiftFloatInputChanged(preset.toString())),
              ),
          ],
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: textTheme.bodyMedium?.copyWith(color: tokens.muted),
                    children: [
                      const TextSpan(
                        text: 'ต้องเปิดกะก่อนรับเงิน · ผู้เปิดกะ: ',
                      ),
                      TextSpan(
                        text: staffName,
                        style: TextStyle(
                          color: tokens.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space4),
                if (isWide)
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.space4),
                    decoration: BoxDecoration(
                      color: tokens.surface2,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                      border: Border.all(color: tokens.line),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(width: 260, child: buildInput()),
                        const SizedBox(width: AppDimensions.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'เลือกยอดด่วน',
                                style: textTheme.labelSmall?.copyWith(
                                  color: tokens.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.space1_5),
                              SizedBox(
                                height: AppDimensions.tap,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: buildPresetRow(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppDimensions.space3),
                        Btn(
                          key: const ValueKey('open-shift-submit-btn'),
                          label: 'เปิดกะ',
                          kind: BtnKind.primary,
                          icon: 'clock',
                          onPressed: () {
                            bloc.add(ShiftOpened(staffId: staffId));
                            onDone?.call();
                          },
                        ),
                      ],
                    ),
                  )
                else ...[
                  buildInput(),
                  const SizedBox(height: AppDimensions.space2_5),
                  buildPresetRow(),
                  const SizedBox(height: AppDimensions.space4),
                  Btn(
                    key: const ValueKey('open-shift-submit-btn'),
                    label: 'เปิดกะ',
                    kind: BtnKind.primary,
                    size: BtnSize.lg,
                    icon: 'clock',
                    block: true,
                    onPressed: () {
                      bloc.add(ShiftOpened(staffId: staffId));
                      onDone?.call();
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// Modal dialog wrapping [OpenShiftForm] (`Modal title="เปิดกะการขาย"` in
/// `prototype/index.html`).
class OpenShiftModal extends StatelessWidget {
  const new({
    required this.staffId,
    required this.staffName,
    required this.onClose,
    super.key,
  });

  final String staffId;
  final String staffName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tokens.scrim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space4),
          child: Modal(
            title: 'เปิดกะการขาย',
            onClose: onClose,
            child: OpenShiftForm(
              staffId: staffId,
              staffName: staffName,
              onDone: onClose,
            ),
          ),
        ),
      ),
    );
  }
}
