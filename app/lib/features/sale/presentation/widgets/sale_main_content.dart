import 'package:app/core/layout/shell_bars.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:app/features/sale/presentation/widgets/sale_catalog.dart';
import 'package:app/features/tables/presentation/widgets/table_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Builds the Topbar title row for `SalePage` (`[< โต๊ะ] โต๊ะ A1 [มีลูกค้า]`).
Widget buildSaleTopbarTitle(
  BuildContext context,
  SaleState state,
  DiningTable tb,
  VoidCallback onBackToTables,
) => Row(
  children: [
    Btn(
      key: const ValueKey('sale-back-tables-btn'),
      kind: BtnKind.ghost,
      icon: 'back',
      label: 'โต๊ะ',
      onPressed: onBackToTables,
    ),
    const SizedBox(width: AppDimensions.space2),
    Flexible(
      child: Text(
        'โต๊ะ ${tb.name}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(color: context.tokens.ink, fontWeight: FontWeight.w700),
      ),
    ),
    const SizedBox(width: AppDimensions.space2),
    Pill(
      label: state.openTable != null ? 'มีลูกค้า' : 'เปิดโต๊ะใหม่',
      tone: state.openTable != null ? PillTone.orange : PillTone.neutral,
    ),
  ],
);

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
    this.onRequestViewSlip,
  });

  final SaleState state;
  final DiningTable table;
  final VoidCallback onBackToTables;
  final ValueChanged<String> onSelectTable;
  final VoidCallback onRequestCloseTable;
  final VoidCallback? onRequestOpenShift;
  final VoidCallback? onRequestViewSlip;

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
        icon: c == 'แพ็กเกจ' ? 'package' : AppIcons.forCategory(c),
      );
    }).toList();

    final hasDesktopTopbar = ShellDesktopHeaderScope.maybeOf(context) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasDesktopTopbar) ...[
          buildSaleTopbarTitle(context, state, table, onBackToTables),
          const SizedBox(height: AppDimensions.space3),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
          const SizedBox(height: 12),
          _OccupiedTableBanner(
            state,
            o,
            onRequestCloseTable,
            onRequestViewSlip: onRequestViewSlip,
          ),
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
          const SizedBox(height: 16),
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
  const new(
    this.state,
    this.openTable,
    this.onRequestCloseTable, {
    this.onRequestViewSlip,
  });
  final SaleState state;
  final OpenTableState openTable;
  final VoidCallback onRequestCloseTable;
  final VoidCallback? onRequestViewSlip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final o = openTable;
    final tm = state.timer;
    final due = state.due;
    final totalHeads = o.heads.a + o.heads.c + o.heads.f;
    final isPaidBefore =
        state.effectiveTiming == 'before' && o.billIds.isNotEmpty;
    final pkgName = state.activePackage?.name ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('$totalHeads คน', style: tt.titleMedium),
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
              Pill(
                label: state.effectiveTiming == 'after'
                    ? (due > 0 ? 'รอชำระ ${baht(due)}' : 'ชำระแล้ว')
                    : 'จ่ายก่อนกิน',
                tone: state.effectiveTiming == 'after' && due > 0
                    ? PillTone.orange
                    : PillTone.green,
              ),
              if (onRequestViewSlip != null)
                Btn(
                  key: const ValueKey('banner-pos-slip-btn'),
                  size: BtnSize.sm,
                  icon: 'receipt',
                  label: 'ดูสลิป POS',
                  onPressed: onRequestViewSlip,
                ),
            ],
          ),
          if (isPaidBefore) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ชำระบุฟเฟต์แล้ว ($pkgName) · '
                    'สั่งเครื่องดื่ม/เพิ่มคนได้ หรือกดเก็บโต๊ะเมื่อรับกลุ่มใหม่',
                    style: tt.bodySmall?.copyWith(color: t.muted),
                  ),
                ),
                const SizedBox(width: 8),
                Btn(
                  key: const ValueKey('banner-close-table-btn'),
                  kind: BtnKind.danger,
                  size: BtnSize.sm,
                  label: 'เก็บโต๊ะ',
                  onPressed: onRequestCloseTable,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
