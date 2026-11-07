import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

/// Status pill badge (`พอ` / `ใกล้หมด` / `หมด`) for a [StockBalanceRow].
class StockStatusBadge extends StatelessWidget {
  const new({required this.row, super.key});

  final StockBalanceRow row;

  @override
  Widget build(BuildContext context) => switch (row.status) {
    StockStatus.ok => const Pill(label: 'พอ', tone: PillTone.green),
    StockStatus.low => Pill(
      label: 'ใกล้หมด · สั่ง ${fmtQ(row.need)} ${row.ing.unit}',
      tone: PillTone.orange,
    ),
    StockStatus.out => Pill(
      label: row.need > 0
          ? 'หมด · สั่ง ${fmtQ(row.need)} ${row.ing.unit}'
          : 'หมด',
      tone: PillTone.red,
    ),
  };
}

/// Grid card layout for `StockBalanceTab` (`design/figma/supply_grid.png`).
class BalanceGridView extends StatelessWidget {
  const new({
    required this.rows,
    required this.totalValue,
    required this.costLabel,
    super.key,
  });

  final List<StockBalanceRow> rows;
  final double totalValue;
  final String costLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    if (rows.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppDimensions.r),
          border: Border.all(color: t.line),
        ),
        child: const Empty(
          title: 'ไม่พบวัตถุดิบ',
          text: 'ไม่มีรายการที่ตรงกับคำค้นหาหรือตัวกรองที่เลือก',
        ),
      );
    }

    final cols = AppDimensions.productGridColumns(
      MediaQuery.sizeOf(context).width,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = AppDimensions.space3;
            final cardW = (constraints.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final r in rows)
                  SizedBox(
                    width: cardW,
                    child: _BalanceGridCard(row: r, costLabel: costLabel),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppDimensions.space3),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space4,
            vertical: AppDimensions.space3,
          ),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppDimensions.r),
            border: Border.all(color: t.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'มูลค่าวัตถุดิบคงเหลือรวม',
                style: tt.bodyMedium?.copyWith(
                  color: t.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                baht(totalValue),
                key: const ValueKey('balance-total-value'),
                style: tt.bodyMedium?.copyWith(
                  color: t.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceGridCard extends StatelessWidget {
  const new({required this.row, required this.costLabel});

  final StockBalanceRow row;
  final String costLabel;

  static String _ingredientIcon(String name) {
    if (name.contains('หมู') ||
        name.contains('สันคอ') ||
        name.contains('สามชั้น') ||
        name.contains('ตับ') ||
        name.contains('ไก่') ||
        name.contains('กุ้ง') ||
        name.contains('ปลาหมึก')) {
      return 'meat';
    }
    if (name.contains('ผัก') || name.contains('เห็ด')) return 'veg';
    if (name.contains('วุ้นเส้น') || name.contains('ลูกชิ้น')) return 'noodles';
    if (name.contains('น้ำจิ้ม')) return 'cup';
    if (name.contains('ถ่าน')) return 'flame';
    if (name.contains('ไข่')) return 'box';
    return 'plate';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final iconName = _ingredientIcon(row.ing.name);

    return Container(
      key: ValueKey('balance-grid-card-${row.ing.id}'),
      padding: const EdgeInsets.all(AppDimensions.space3_5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.r),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: t.surface2,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Center(
                  child: AppIcon(
                    iconName,
                    size: AppDimensions.iconLg,
                    color: t.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.space2_5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.ing.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        color: t.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${kLocations[row.ing.location] ?? "-"} · '
                      '$costLabel ${fmtBaht(row.unitCost, 2)} ฿/${row.ing.unit}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space2_5),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space2_5,
              vertical: AppDimensions.space1_5,
            ),
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ควรมี ${fmtQ(row.ing.par)} ${row.ing.unit}',
                  style: tt.labelSmall?.copyWith(color: t.muted),
                ),
                Text(
                  'มูลค่า ${baht(row.val)}',
                  style: tt.labelSmall?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space2_5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${fmtQ(row.qty)} ${row.ing.unit}',
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.space1_5),
              StockStatusBadge(row: row),
            ],
          ),
        ],
      ),
    );
  }
}
