import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:app/features/stock/presentation/widgets/stock_balance_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/stock/presentation/widgets/stock_balance_grid.dart';

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
    final allFiltered = state.filteredBalanceRows;
    final okCount = allFiltered.where((r) => r.status == StockStatus.ok).length;
    final lowCount = allFiltered
        .where((r) => r.status == StockStatus.low)
        .length;
    final outCount = allFiltered
        .where((r) => r.status == StockStatus.out)
        .length;
    final needCount = lowCount + outCount;
    final hasActiveFilters =
        state.activeFilterCount > 0 || state.searchQuery.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatsGroup(
            children: [
              Stat(
                label: 'มูลค่าคงเหลือรวม',
                value: baht(state.totalBalanceValue),
                sub: '${allFiltered.length} รายการวัตถุดิบ',
              ),
              Stat(
                label: 'ต้องสั่งซื้อเพิ่ม',
                value: '$needCount รายการ',
                sub: outCount > 0
                    ? 'หมดสต็อก $outCount · ใกล้หมด $lowCount'
                    : (lowCount > 0
                          ? 'ใกล้หมด $lowCount รายการ'
                          : 'ไม่มีรายการต้องสั่งเพิ่ม'),
                tone: needCount > 0 ? StatTone.red : StatTone.green,
              ),
              Stat(
                label: 'สต็อกเพียงพอ',
                value: '$okCount รายการ',
                sub: 'พร้อมใช้งานตามเกณฑ์',
                tone: StatTone.green,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space3),
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
          if (hasActiveFilters) ...[
            const SizedBox(height: AppDimensions.space3),
            Wrap(
              key: const ValueKey('stock-active-filters-bar'),
              spacing: AppDimensions.space2,
              runSpacing: AppDimensions.space1_5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'ตัวกรอง:',
                  style: tt.labelSmall?.copyWith(color: t.muted),
                ),
                for (final loc in state.locationFilters)
                  Pill(tone: PillTone.orange, label: kLocations[loc] ?? loc),
                if (state.statusFilter != 'all')
                  Pill(
                    tone: switch (state.statusFilter) {
                      'ok' => PillTone.green,
                      'out' => PillTone.red,
                      _ => PillTone.orange,
                    },
                    label: switch (state.statusFilter) {
                      'ok' => 'สถานะ: พอ',
                      'low' => 'สถานะ: ใกล้หมด',
                      _ => 'สถานะ: หมด',
                    },
                  ),
                if (state.searchQuery.trim().isNotEmpty)
                  Pill(label: 'ค้นหา "${state.searchQuery.trim()}"'),
                Btn(
                  key: const ValueKey('stock-inline-clear-filters-btn'),
                  kind: BtnKind.ghost,
                  size: BtnSize.sm,
                  icon: 'x',
                  label: 'ล้างตัวกรอง',
                  onPressed: () {
                    cubit
                      ..clearFilters()
                      ..setSearchQuery('');
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: AppDimensions.space4),
          if (state.balanceViewMode == 'grid')
            BalanceGridView(
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
                    fmtBaht(r.unitCost, 2),
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
                    fmtBaht(r.val),
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
                    child: StockStatusBadge(row: r),
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
