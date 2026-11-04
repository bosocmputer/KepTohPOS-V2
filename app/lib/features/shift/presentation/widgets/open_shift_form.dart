import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                style: textTheme.bodyMedium?.copyWith(color: tokens.ink),
                children: [
                  const TextSpan(text: 'ต้องเปิดกะก่อนรับเงิน ผู้เปิดกะ: '),
                  TextSpan(
                    text: staffName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space4),
            Field(
              label: 'เงินทอนตั้งต้นในลิ้นชัก (บาท)',
              child: AppTextInput(
                key: const ValueKey('shift-float-input'),
                value: state.floatInput,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) => bloc.add(ShiftFloatInputChanged(v)),
              ),
            ),
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
