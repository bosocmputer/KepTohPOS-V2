import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/widgets/sale_receipt_modal.dart';
import 'package:app/features/tables/presentation/cubit/tables_cubit.dart';
import 'package:app/features/tables/presentation/widgets/table_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/tables/presentation/cubit/tables_cubit.dart';
export 'package:app/features/tables/presentation/widgets/table_card.dart';

/// Builds the zone filter dropdown (`tables-zone-dropdown`) shown in the
/// unified Topbar on tablet/desktop and inline on mobile (`<= 760px`).
Widget buildTablesZoneDropdown(TablesCubit cubit, TablesState state) =>
    SizedBox(
      width: 172,
      child: Dropdown<String>(
        key: const ValueKey('tables-zone-dropdown'),
        value: state.selectedZone,
        options: <DropdownOption<String>>[
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
        ],
        onChanged: cubit.selectZone,
      ),
    );

/// Floor and table overview screen (`function TablesView` in
/// `prototype/index.html` & `design/figma/table.png`).
class TablesPage extends StatefulWidget {
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
  State<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends State<TablesPage> {
  String? _slipTableId;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;

    return BlocBuilder<TablesCubit, TablesState>(
      builder: (context, state) {
        final cubit = context.read<TablesCubit>();
        final screenW = MediaQuery.sizeOf(context).width;
        final isMobile = screenW <= AppDimensions.mobileBp;
        final pagePad = AppDimensions.pagePadding(screenW);
        final slip = _slipTableId != null
            ? cubit.tablePosSlip(_slipTableId!)
            : null;
        final defaultStaff = state.posState.staff.firstOrNull;

        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(pagePad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMobile) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: buildTablesZoneDropdown(cubit, state),
                    ),
                    const SizedBox(height: AppDimensions.space3),
                  ],
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
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
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
                          if (widget.onRequestOpenShift != null)
                            Btn(
                              key: const ValueKey('tables-open-shift-btn'),
                              label: 'เปิดกะ',
                              kind: BtnKind.primary,
                              size: BtnSize.sm,
                              onPressed: widget.onRequestOpenShift,
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
                        action: widget.onGoSetupTables != null
                            ? Btn(
                                label: 'ไปตั้งค่าโต๊ะ',
                                kind: BtnKind.primary,
                                onPressed: widget.onGoSetupTables,
                              )
                            : null,
                      ),
                    )
                  else
                    for (final z in state.visibleZones) ...[
                      _ZoneTablesSection(
                        zone: z,
                        state: state,
                        onSelectTable: widget.onSelectTable,
                        onViewSlip: (tableId) =>
                            setState(() => _slipTableId = tableId),
                      ),
                      const SizedBox(height: AppDimensions.space5),
                    ],
                ],
              ),
            ),
            if (slip != null && _slipTableId != null)
              ReceiptModal(
                shop: state.posState.shop,
                bill: slip,
                fresh: false,
                staff: defaultStaff,
                allowCashierVoid: true,
                tableSummary: buildTableSummarySlip(
                  state.posState,
                  _slipTableId!,
                  now: state.now,
                ),
                onPrint: () =>
                    showAppToast(context, 'ส่งพิมพ์สลิป POS แล้ว (จำลอง)'),
                onVoid: defaultStaff == null
                    ? null
                    : (reason) async {
                        await cubit.voidBill(slip.id, reason, defaultStaff);
                        if (!context.mounted) return;
                        setState(() => _slipTableId = null);
                        showAppToast(
                          context,
                          'ยกเลิกบิลและคืนสถานะโต๊ะเรียบร้อย',
                        );
                      },
                onVoidSubBill: defaultStaff == null
                    ? null
                    : (billId, reason) async {
                        await cubit.voidBill(billId, reason, defaultStaff);
                        if (!context.mounted) return;
                        showAppToast(context, 'ยกเลิกบิลย่อยเรียบร้อย');
                      },
                onCancelTable: () async {
                  await cubit.cancelTable(_slipTableId!);
                  if (!context.mounted) return;
                  setState(() => _slipTableId = null);
                  showAppToast(context, 'ยกเลิกรายการโต๊ะเรียบร้อย');
                },
                onDone: () => setState(() => _slipTableId = null),
              ),
          ],
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
    required this.onViewSlip,
  });

  final String zone;
  final TablesState state;
  final ValueChanged<String> onSelectTable;
  final ValueChanged<String> onViewSlip;

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
                      onViewSlip: state.posState.openTables[tb.id] != null
                          ? () => onViewSlip(tb.id)
                          : null,
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
