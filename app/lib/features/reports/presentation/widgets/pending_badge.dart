import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Badge indicating formulas use provisional defaults (`PendingBadge` in
/// `prototype/index.html:1528`).
class PendingBadge extends StatelessWidget {
  const new({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const pill = Pill(
      key: ValueKey('pending-badge'),
      tone: PillTone.orange,
      label: 'ค่าตั้งต้น · รอยืนยันกับร้าน',
    );
    return onTap == null
        ? pill
        : InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            onTap: onTap,
            child: pill,
          );
  }
}
