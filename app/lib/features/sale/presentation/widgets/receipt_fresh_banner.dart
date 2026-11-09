import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

/// Green "รับเงินเรียบร้อย" banner shown above a freshly settled receipt.
class ReceiptFreshBanner extends StatelessWidget {
  const new({required this.bill, super.key});

  final BillRecord bill;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final changeTxt = baht(bill.change, bill.change % 100 != 0 ? 2 : 0);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space4,
        vertical: AppDimensions.space3,
      ),
      decoration: BoxDecoration(
        color: t.successSoft,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: t.success),
      ),
      child: Row(
        children: [
          Container(
            width: AppDimensions.space9,
            height: AppDimensions.space9,
            decoration: BoxDecoration(color: t.success, shape: BoxShape.circle),
            child: Center(child: AppIcon('check', color: t.onPrimary)),
          ),
          const SizedBox(width: AppDimensions.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'รับเงินเรียบร้อย',
                  style: tt.titleMedium?.copyWith(
                    color: t.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'ชำระผ่าน ${bill.methodName}',
                  style: tt.labelSmall?.copyWith(color: t.ink),
                ),
              ],
            ),
          ),
          if (bill.methodType == 'cash')
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'เงินทอน',
                  style: tt.labelSmall?.copyWith(
                    color: t.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  changeTxt,
                  style: tt.headlineMedium?.copyWith(
                    color: t.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
