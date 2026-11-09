import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/btn.dart';
import 'package:app/core/widgets/modal.dart';
import 'package:flutter/material.dart';

/// Confirmation dialog (`Confirm` in `prototype/index.html`).
class Confirm extends StatelessWidget {
  const new({
    required this.title,
    required this.text,
    required this.onYes,
    required this.onNo,
    super.key,
    this.yesLabel = 'ยืนยัน',
    this.danger = false,
    this.child,
    this.yesKey,
    this.noKey,
  });

  final String title;
  final String text;
  final String yesLabel;
  final bool danger;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final Widget? child;
  final Key? yesKey;
  final Key? noKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Modal(
      title: title,
      onClose: onNo,
      footer: [
        Btn(key: noKey, label: 'ยกเลิก', onPressed: onNo),
        Btn(
          key: yesKey,
          label: yesLabel,
          kind: danger ? BtnKind.dangerSolid : BtnKind.primary,
          onPressed: onYes,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: tokens.ink),
          ),
          if (child != null) ...[
            const SizedBox(height: AppDimensions.space3),
            child!,
          ],
        ],
      ),
    );
  }
}
