import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/tables/presentation/cubit/tables_cubit.dart';
import 'package:app/features/tables/presentation/widgets/table_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/tables/presentation/cubit/tables_cubit.dart';
export 'package:app/features/tables/presentation/widgets/table_card.dart';

/// Floor and table overview screen (`function TablesView` in
/// `prototype/index.html` & `design/figma/table.png`).
class TablesPage extends StatelessWidget {
  const new({
    required this.onSelectTable,
    super.key,
    this.onRequestOpenShift,
    this.onGoSetupTables,
  });

  final ValueChanged<String> onSelectTable;
  final VoidCallback? onRequestOpenShift;
  final VoidCallback? onGoSetupTables;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;

    return BlocBuilder<TablesCubit, TablesState>(
      builder: (context, state) {
        final cubit = context.read<TablesCubit>();
        final zoneOptions = <DropdownOption<String>>[
          DropdownOption<String>(
            value: 'all',
            label: 'ทุกโซน',
            sub: '${state.totalTables} โต๊ะ',
          ),
          for (final z in state.zones)
            DropdownOption<String>(
              value: z,
              label: z,
              sub: 'ว่าง ${state.freeInZone(z)} จาก ${state.totalInZone(z)}',
            ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'โต๊ะและการขาย',
                desc: 'ภาพรวมโต๊ะว่าง ลูกค้าในร้าน และสถานะรอชำระ',
                actions: [
                  SizedBox(
                    width: 200,
                    child: SearchBox(
                      key: const ValueKey('tables-search-box'),
                      value: state.searchQuery,
                      placeholder: 'ค้นหาโต๊ะ',
                      onChanged: cubit.setSearchQuery,
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: Dropdown<String>(
                      key: const ValueKey('tables-zone-dropdown'),
                      value: state.selectedZone,
                      options: zoneOptions,
                      onChanged: cubit.selectZone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space5),
              StatsGroup(
                children: [
                  Stat(
                    label: 'โต๊ะว่าง',
                    value: '${state.freeCount} / ${state.totalTables}',
                  ),
                  Stat(
                    label: 'ลูกค้าในร้านตอนนี้',
                    value: '${state.inStoreHeads} คน',
                  ),
                  Stat(
                    label: 'ยอดขายวันนี้',
                    value: baht(state.todaySalesTotal),
                    sub:
                        '${state.todayBillsCount} บิล · '
                        '${state.todayPaidHeads} หัว',
                  ),
                  if (state.owingTablesCount > 0)
                    Stat(
                      label: 'ค้างชำระ (กินก่อนจ่าย)',
                      value: baht(state.owingTotal),
                      tone: StatTone.red,
                      sub: '${state.owingTablesCount} โต๊ะ',
                    ),
                ],
              ),
              if (!state.hasOpenShift) ...[
                const SizedBox(height: AppDimensions.space4),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.space4),
                  decoration: BoxDecoration(
                    color: t.primarySoft,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ยังไม่เปิดกะ ต้องเปิดกะก่อนจึงรับเงินได้',
                          style: tt.bodyMedium?.copyWith(
                            color: t.primaryInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (onRequestOpenShift != null)
                        Btn(
                          key: const ValueKey('tables-open-shift-btn'),
                          label: 'เปิดกะ',
                          kind: BtnKind.primary,
                          size: BtnSize.sm,
                          onPressed: onRequestOpenShift,
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.space5),
              if (state.posState.tables.isEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.r),
                    border: Border.all(color: t.line),
                  ),
                  child: Empty(
                    title: 'ยังไม่มีโต๊ะ',
                    text: 'เพิ่มโต๊ะที่ ตั้งค่า › โต๊ะ',
                    action: onGoSetupTables != null
                        ? Btn(
                            label: 'ไปตั้งค่าโต๊ะ',
                            kind: BtnKind.primary,
                            onPressed: onGoSetupTables,
                          )
                        : null,
                  ),
                )
              else
                for (final z in state.visibleZones) ...[
                  _ZoneTablesSection(
                    zone: z,
                    state: state,
                    onSelectTable: onSelectTable,
                  ),
                  const SizedBox(height: AppDimensions.space5),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _ZoneTablesSection extends StatelessWidget {
  const new({
    required this.zone,
    required this.state,
    required this.onSelectTable,
  });

  final String zone;
  final TablesState state;
  final ValueChanged<String> onSelectTable;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final tables = state.tablesInZone(zone);
    if (tables.isEmpty) return const SizedBox.shrink();
    final free = state.freeInZone(zone);
    final total = state.totalInZone(zone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(zone, style: tt.headlineMedium?.copyWith(color: t.ink)),
            const SizedBox(width: AppDimensions.space2_5),
            Text(
              'ว่าง $free จาก $total',
              style: tt.bodySmall?.copyWith(color: t.muted),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space3),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cols = w >= 1100 ? 5 : (w >= 840 ? 4 : (w >= 560 ? 3 : 2));
            const spacing = AppDimensions.space3;
            final itemW = (w - (cols - 1) * spacing) / cols;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final tb in tables)
                  SizedBox(
                    width: itemW,
                    child: TableCard(
                      posState: state.posState,
                      table: tb,
                      openTable: state.posState.openTables[tb.id],
                      now: state.now,
                      onTap: () => onSelectTable(tb.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
