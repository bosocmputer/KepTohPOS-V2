import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/app_icon.dart';
import 'package:app/core/widgets/pill.dart';
import 'package:flutter/material.dart';

/// Product / menu card with image or placeholder (`ProductCard` per Figma
/// `design/figma/cashier.png`). Never embeds the Figma burger photos.
class ProductCard extends StatelessWidget {
  const new({
    required this.name,
    required this.price,
    super.key,
    this.category,
    this.subtitle,
    this.stock,
    this.icon = 'cup',
    this.selected = false,
    this.onTap,
  });

  final String name;
  final double price;
  final String? category;
  final String? subtitle;
  final int? stock;
  final String icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final outOfStock = stock != null && stock! <= 0;

    return Opacity(
      opacity: outOfStock ? 0.5 : 1,
      child: Material(
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(
            color: selected ? tokens.primary : tokens.line,
            width: selected
                ? AppDimensions.borderBold
                : AppDimensions.borderThin,
          ),
        ),
        child: InkWell(
          onTap: outOfStock ? null : onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: AppDimensions.productCardImgH,
                  decoration: BoxDecoration(
                    color: selected ? tokens.primarySoft : tokens.surface2,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: AppIcon(
                          icon,
                          size: AppDimensions.icon2xl,
                          color: selected ? tokens.primary : tokens.muted,
                        ),
                      ),
                      if (stock != null)
                        Positioned(
                          right: AppDimensions.space2,
                          top: AppDimensions.space2,
                          child: Pill(
                            label: outOfStock ? 'หมด' : 'เหลือ $stock',
                            tone: outOfStock ? PillTone.red : PillTone.neutral,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space2_5),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spaceHalf),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: tokens.muted,
                      fontSize: AppDimensions.fsXs,
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.space2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (category != null && category!.isNotEmpty)
                      Flexible(
                        child: Pill(label: category, tone: PillTone.orange),
                      )
                    else
                      const SizedBox.shrink(),
                    Text(
                      baht(price),
                      style: textTheme.titleLarge?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
