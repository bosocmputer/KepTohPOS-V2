import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:app/features/sale/presentation/widgets/sale_catalog.dart';
import 'package:app/features/tables/presentation/widgets/table_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Left-hand main product/package selection area of `SalePage` (`div.sale-main`
/// in `prototype/index.html` & `design/figma/cashier.png`).
class SaleMainContent extends StatelessWidget {
  const new({
    required this.state,
    required this.table,
    required this.onBackToTables,
    required this.onSelectTable,
    required this.onRequestCloseTable,
    super.key,
    this.onRequestOpenShift,
  });

  final SaleState state;
  final DiningTable table;
  final VoidCallback onBackToTables;
  final ValueChanged<String> onSelectTable;
  final VoidCallback onRequestCloseTable;
  final VoidCallback? onRequestOpenShift;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final bloc = context.read<SaleBloc>();
    final s = state.posState;
    final o = state.openTable;
    final hasShift = openShiftOf(s) != null;
    final curCat = state.activeCategory;
    final openTablesList = s.tables
        .where((x) => s.openTables.containsKey(x.id))
        .toList();

    final tabItems = state.categories.map((c) {
      final count = c == 'แพ็กเกจ'
          ? state.activePackages.length
          : state.activeAddons
                .where(
                  (x) =>
                      (x.category.isNotEmpty ? x.category : 'เครื่องดื่ม') == c,
                )
                .length;
      return TabItem<String>(
        value: c,
        label: c,
        count: count,
        icon: c == 'แพ็กเกจ' ? 'tables' : 'cup',
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Btn(
              key: const ValueKey('sale-back-tables-btn'),
              kind: BtnKind.ghost,
              icon: 'back',
              label: 'โต๊ะ',
              onPressed: onBackToTables,
            ),
            const SizedBox(width: AppDimensions.space2),
            Text(
              'โต๊ะ ${table.name}',
              style: tt.headlineLarge?.copyWith(color: t.ink),
            ),
            const SizedBox(width: AppDimensions.space2_5),
            Pill(
              label: o != null ? 'มีลูกค้า' : 'เปิดโต๊ะใหม่',
              tone: o != null ? PillTone.orange : PillTone.neutral,
            ),
            const Spacer(),
            if (o != null)
              Btn(
                key: const ValueKey('sale-close-table-btn'),
                icon: 'check',
                label: 'เก็บโต๊ะ',
                onPressed: onRequestCloseTable,
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.space3),
        Wrap(
          spacing: AppDimensions.space2,
          runSpacing: AppDimensions.space2,
          children: [
            if (o == null)
              TableChip(
                posState: s,
                table: table,
                active: true,
                now: state.now,
                onTap: () {},
              ),
            for (final x in openTablesList)
              TableChip(
                posState: s,
                table: x,
                openTable: s.openTables[x.id],
                active: x.id == state.tableId,
                now: state.now,
                onTap: () => onSelectTable(x.id),
              ),
          ],
        ),
        if (o != null) ...[
          const SizedBox(height: AppDimensions.space3),
          _OccupiedTableBanner(state: state, openTable: o),
        ],
        if (!hasShift) ...[
          const SizedBox(height: AppDimensions.space3),
          Container(
            padding: const EdgeInsets.all(AppDimensions.space3),
            decoration: BoxDecoration(
              color: t.primarySoft,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ยังไม่เปิดกะ ต้องเปิดกะก่อนจึงรับเงินได้ '
                    '(ส่งออเดอร์ได้ตามปกติ)',
                    style: tt.bodySmall?.copyWith(
                      color: t.primaryInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onRequestOpenShift != null)
                  Btn(
                    label: 'เปิดกะ',
                    kind: BtnKind.primary,
                    size: BtnSize.sm,
                    onPressed: onRequestOpenShift,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppDimensions.space4),
        if (tabItems.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppDimensions.r),
              border: Border.all(color: t.line),
            ),
            child: const Empty(
              title: 'ยังไม่มีรายการขาย',
              text: 'เพิ่มแพ็กเกจหรือสินค้าขายเสริมที่ ตั้งค่า',
            ),
          )
        else ...[
          Tabs<String>(
            value: curCat,
            items: tabItems,
            onChanged: (c) => bloc.add(SaleCategorySelected(c)),
          ),
          const SizedBox(height: AppDimensions.space4),
          if (curCat == 'แพ็กเกจ')
            SalePackagesList(state: state)
          else
            SaleAddonsGrid(state: state, category: curCat),
        ],
      ],
    );
  }
}

class _OccupiedTableBanner extends StatelessWidget {
  const new({required this.state, required this.openTable});
  final SaleState state;
  final OpenTableState openTable;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final o = openTable;
    final tm = state.timer;
    final due = state.due;
    final totalHeads = o.heads.a + o.heads.c + o.heads.f;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space3),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: t.line),
      ),
      child: Wrap(
        spacing: AppDimensions.space3,
        runSpacing: AppDimensions.space1,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$totalHeads คน',
            style: tt.bodyMedium?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'ผู้ใหญ่ ${o.heads.a} · เด็ก ${o.heads.c} · ฟรี ${o.heads.f}',
            style: tt.bodySmall?.copyWith(color: t.muted),
          ),
          if (tm != null)
            Text(
              tm.text,
              style: tt.bodySmall?.copyWith(
                color: tm.late ? t.danger : t.muted,
                fontWeight: tm.late ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          if (state.effectiveTiming == 'after')
            Pill(
              label: due > 0 ? 'รอชำระ ${baht(due)}' : 'ชำระแล้ว',
              tone: due > 0 ? PillTone.orange : PillTone.green,
            )
          else
            const Pill(label: 'จ่ายก่อนกิน'),
        ],
      ),
    );
  }
}
