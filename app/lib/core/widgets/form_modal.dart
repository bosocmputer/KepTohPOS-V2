import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/btn.dart';
import 'package:app/core/widgets/modal.dart';
import 'package:flutter/material.dart';

/// [Modal] preset for forms: fields, optional error, cancel + primary actions.
class FormModal extends StatelessWidget {
  const new({
    required this.title,
    required this.children,
    required this.onSubmit,
    required this.onCancel,
    super.key,
    this.sub,
    this.error,
    this.submitLabel = 'บันทึก',
    this.cancelLabel = 'ยกเลิก',
    this.busy = false,
    this.submitDisabled = false,
  });

  final String title;
  final String? sub;
  final List<Widget> children;
  final String? error;
  final String submitLabel;
  final String cancelLabel;
  final bool busy;
  final bool submitDisabled;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasError = error != null && error!.isNotEmpty;
    return Modal(
      title: title,
      sub: sub,
      onClose: busy ? null : onCancel,
      footer: [
        Btn(label: cancelLabel, disabled: busy, onPressed: onCancel),
        Btn(
          label: submitLabel,
          kind: BtnKind.primary,
          loading: busy,
          disabled: submitDisabled,
          onPressed: onSubmit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: AppDimensions.space3_5,
        children: [
          ...children,
          if (hasError)
            Text(
              error!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: tokens.danger),
            ),
        ],
      ),
    );
  }
}
