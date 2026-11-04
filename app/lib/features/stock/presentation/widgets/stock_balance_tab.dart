import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Stock balance & reorder recommendation tab (`StockBalance` in
/// `prototype/index.html:1482-1497` & `design/figma/supply_list.png`,
/// `design/figma/supply_grid.png`).
class StockBalanceTab extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final state = context.watch<StockCubit>().state;
    final cubit = context.read<StockCubit>();
    final rows = state.pagedBalanceRows;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space4,
              vertical: AppDimensions.space3,
            ),
            decoration: BoxDecoration(
              color: t.primarySoft,
              borderRadius: BorderRadius.circular(AppDimensions.r),
              border: Border.all(color: t.primary),
            ),
            child: Text(
              'คงเหลือล่าสุด = นับครั้งล่าสุด + ซื้อเข้าหลังจากนั้น '
              '(ของนับรายสัปดาห์หักค่าประมาณแล้ว) · '
              'แนะนำสั่งซื้อ = ระดับที่ควรมี − คงเหลือ',
              style: tt.bodySmall?.copyWith(
                color: t.primaryInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space4),
          if (state.balanceViewMode == 'grid')
            _BalanceGridView(
              rows: rows,
              totalValue: state.totalBalanceValue,
              costLabel: state.costColumnLabel,
            )
          else
            PosDataTable<StockBalanceRow>(
              rows: rows,
              empty: const Empty(
                title: 'ไม่พบวัตถุดิบ',
                text: 'ไม่มีรายการที่ตรงกับคำค้นหาหรือตัวกรองที่เลือก',
              ),
              columns: [
                DataTableCol<StockBalanceRow>(
                  key: 'name',
                  label: 'วัตถุดิบ',
                  flex: 3,
                  cellBuilder: (context, r) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.ing.name,
                        style: tt.bodyMedium?.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${kLocations[r.ing.location] ?? "-"} · '
                        '${kCountFreqs[r.ing.countFreq] ?? "-"}',
                        style: tt.labelSmall?.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                DataTableCol<StockBalanceRow>(
                  key: 'sup',
                  label: 'ซื้อจาก',
                  flex: 2,
                  cellBuilder: (context, r) => Text(
                    r.supplierName,
                    style: tt.bodySmall?.copyWith(color: t.muted),
                  ),
                ),
                DataTableCol<StockBalanceRow>(
                  key: 'qty',
                  label: 'คงเหลือ',
                  align: ColAlign.right,
                  cellBuilder: (context, r) => Text(
                    '${fmtQ(r.qty)} ${r.ing.unit}',
                    textAlign: TextAlign.right,
                    style: tt.bodyMedium?.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataTableCol<StockBalanceRow>(
                  key: 'cost',
                  label: state.costColumnLabel,
                  align: ColAlign.right,
                  cellBuilder: (context, r) => Text(
                    fmt(r.unitCost, 2),
                    key: ValueKey('balance-unit-cost-${r.ing.id}'),
                    textAlign: TextAlign.right,
                    style: tt.bodyMedium?.copyWith(color: t.ink),
                  ),
                ),
                DataTableCol<StockBalanceRow>(
                  key: 'val',
                  label: 'มูลค่าคงเหลือ',
                  align: ColAlign.right,
                  cellBuilder: (context, r) => Text(
                    fmt(r.val),
                    key: ValueKey('balance-val-${r.ing.id}'),
                    textAlign: TextAlign.right,
                    style: tt.bodyMedium?.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DataTableCol<StockBalanceRow>(
                  key: 'par',
                  label: 'ระดับที่ควรมี',
                  align: ColAlign.right,
                  cellBuilder: (context, r) => Text(
                    fmtQ(r.ing.par),
                    textAlign: TextAlign.right,
                    style: tt.bodyMedium?.copyWith(color: t.muted),
                  ),
                ),
                DataTableCol<StockBalanceRow>(
                  key: 'need',
                  label: 'แนะนำสั่งซื้อ',
                  flex: 2,
                  align: ColAlign.right,
                  cellBuilder: (context, r) => Align(
                    alignment: Alignment.centerRight,
                    child: _StockStatusBadge(row: r),
                  ),
                ),
              ],
              footerCells: [
                const Text('มูลค่าวัตถุดิบคงเหลือรวม'),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    baht(state.totalBalanceValue),
                    key: const ValueKey('balance-total-value'),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppDimensions.space3),
          Pagination(
            page: state.effectiveBalancePage,
            pages: state.balanceTotalPages,
            onChanged: cubit.setBalancePage,
          ),
        ],
      ),
    );
  }
}

class _StockStatusBadge extends StatelessWidget {
  const new({required this.row});

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

class _BalanceGridView extends StatelessWidget {
  const new({
    required this.rows,
    required this.totalValue,
    required this.costLabel,
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final iconName = AppIcons.forCategory(row.ing.name);

    return Container(
      key: ValueKey('balance-grid-card-${row.ing.id}'),
      padding: const EdgeInsets.all(AppDimensions.space3),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.r),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 76,
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Center(
              child: AppIcon(
                iconName,
                size: AppDimensions.icon2xl,
                color: t.primary,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space2_5),
          Text(
            row.ing.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.titleMedium?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceHalf),
          Text(
            '${kLocations[row.ing.location] ?? "-"} · '
            '$costLabel ${fmt(row.unitCost, 2)} ฿/${row.ing.unit}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelSmall?.copyWith(color: t.muted),
          ),
          const SizedBox(height: AppDimensions.space2_5),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space2_5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${fmtQ(row.qty)} ${row.ing.unit}',
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.space1_5),
              _StockStatusBadge(row: row),
            ],
          ),
        ],
      ),
    );
  }
}
