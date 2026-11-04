import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/btn.dart';
import 'package:flutter/material.dart';

/// Page selector bar (`Pagination` in `prototype/index.html` & Figma History).
class Pagination extends StatelessWidget {
  const new({
    required this.page,
    required this.pages,
    required this.onChanged,
    super.key,
  });

  final int page;
  final int pages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (pages <= 1) return const SizedBox.shrink();
    final tokens = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'หน้า $page จาก $pages',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: tokens.muted),
        ),
        Wrap(
          spacing: AppDimensions.space1,
          children: List<Widget>.generate(pages, (index) {
            final n = index + 1;
            final active = n == page;
            return Btn(
              label: '$n',
              size: BtnSize.sm,
              kind: active ? BtnKind.primary : BtnKind.normal,
              onPressed: () => onChanged(n),
            );
          }),
        ),
      ],
    );
  }
}
