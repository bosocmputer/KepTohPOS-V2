import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/bills/presentation/widgets/bills_filter_drawer.dart';
import 'package:app/features/sale/presentation/widgets/sale_receipt_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Daily sales bills history screen (`BillsView` in `prototype/index.html` &
/// `design/figma/history.png`).
class BillsPage extends StatelessWidget {
  const new({required this.staff, super.key});

  final StaffMember staff;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final state = context.watch<BillsCubit>().state;
    final cubit = context.read<BillsCubit>();
    final selectedBill = state.selectedBill;

    return BlocListener<BillsCubit, BillsState>(
      listenWhen: (prev, curr) =>
          curr.toastMessage.isNotEmpty &&
          curr.toastMessage != prev.toastMessage,
      listener: (context, s) {
        showAppToast(context, s.toastMessage);
        context.read<BillsCubit>().clearToast();
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.space6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'บิลขาย',
                  desc:
                      'รายการใบเสร็จรับเงิน ยอดแยกตามช่องทาง '
                      'และประวัติการยกเลิกบิล',
                  actions: [
                    SizedBox(
                      width: 220,
                      child: Dropdown<String>(
                        key: const ValueKey('bills-date-dropdown'),
                        value: state.selectedDate,
                        onChanged: cubit.setDate,
                        options: [
                          for (final d in state.availableDates)
                            DropdownOption<String>(
                              value: d,
                              label: d == state.todayDate
                                  ? 'วันนี้ · ${thDate(d)}'
                                  : thDate(d),
                            ),
                        ],
                      ),
                    ),
                    Btn(
                      key: const ValueKey('bills-filter-btn'),
                      icon: 'filter',
                      kind: state.activeFilterCount > 0
                          ? BtnKind.primary
                          : BtnKind.normal,
                      label: state.activeFilterCount > 0
                          ? 'ตัวกรอง (${state.activeFilterCount})'
                          : 'ตัวกรอง',
                      onPressed: () => cubit.setFilterDrawerOpen(open: true),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space5),
                StatsGroup(
                  key: const ValueKey('bills-stats-group'),
                  children: [
                    Stat(
                      label: 'ยอดขาย (${thDate(state.selectedDate)})',
                      value: baht(state.totalSales),
                      sub: '${state.okBills.length} บิลที่ชำระสำเร็จ',
                      tone: StatTone.green,
                    ),
                    Stat(
                      label: 'จำนวนบิล',
                      value: '${state.okBills.length}',
                      sub: state.voidedCount > 0
                          ? 'ยกเลิก ${state.voidedCount} บิล'
                          : 'ไม่มีบิลยกเลิก',
                    ),
                    Stat(
                      label: 'ลูกค้า (หัว)',
                      value: '${state.totalPaidHeads}',
                      sub: 'ทานฟรี ${state.totalFreeHeads} คน',
                    ),
                  ],
                ),
                if (state.salesByMethod.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.space3),
                  Container(
                    key: const ValueKey('bills-method-summary'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space4,
                      vertical: AppDimensions.space3,
                    ),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.r),
                      border: Border.all(color: t.line),
                    ),
                    child: Wrap(
                      spacing: AppDimensions.space5,
                      runSpacing: AppDimensions.space2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'แยกตามช่องทาง:',
                          style: tt.labelMedium?.copyWith(color: t.muted),
                        ),
                        for (final entry in state.salesByMethod.entries)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${entry.key}: ',
                                style: tt.bodySmall?.copyWith(color: t.muted),
                              ),
                              Text(
                                baht(entry.value),
                                style: tt.bodyMedium?.copyWith(
                                  color: t.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.space4),
                PosDataTable<BillRecord>(
                  rows: state.pagedBills,
                  onRowTap: (b) => cubit.selectBill(b.id),
                  empty: const Empty(
                    title: 'ไม่มีบิล',
                    text: 'ยังไม่มีรายการขายตามเงื่อนไขที่เลือก',
                  ),
                  columns: [
                    DataTableCol<BillRecord>(
                      key: 'no',
                      label: 'เลขที่',
                      flex: 2,
                      cellBuilder: (context, b) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              b.no,
                              key: ValueKey('bill-row-no-${b.id}'),
                              style: tt.bodyMedium?.copyWith(
                                color: t.ink,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (b.voided) ...[
                            const SizedBox(width: AppDimensions.space1_5),
                            const Pill(label: 'ยกเลิก', tone: PillTone.red),
                          ],
                        ],
                      ),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'at',
                      label: 'เวลา',
                      cellBuilder: (context, b) => Text(
                        thTime(b.at),
                        style: tt.bodyMedium?.copyWith(color: t.ink),
                      ),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'table',
                      label: 'โต๊ะ',
                      cellBuilder: (context, b) => Text(
                        b.tableName,
                        style: tt.bodyMedium?.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'heads',
                      label: 'ลูกค้า',
                      cellBuilder: (context, b) => Text(
                        '${b.heads.a + b.heads.c + b.heads.f} คน',
                        style: tt.bodyMedium?.copyWith(color: t.ink),
                      ),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'method',
                      label: 'ชำระโดย',
                      flex: 2,
                      cellBuilder: (context, b) => Text(
                        b.methodName,
                        style: tt.bodyMedium?.copyWith(color: t.ink),
                      ),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'staff',
                      label: 'แคชเชียร์',
                      flex: 2,
                      cellBuilder: (context, b) => Text(
                        b.staffName,
                        style: tt.bodyMedium?.copyWith(color: t.ink),
                      ),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'total',
                      label: 'ยอด',
                      flex: 2,
                      align: ColAlign.right,
                      cellBuilder: (context, b) => Text(
                        baht(b.total, 2),
                        textAlign: TextAlign.right,
                        style: tt.bodyMedium?.copyWith(
                          color: b.voided ? t.muted : t.ink,
                          fontWeight: FontWeight.w700,
                          decoration: b.voided
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space3),
                Pagination(
                  page: state.currentPage,
                  pages: state.totalPages,
                  onChanged: cubit.setPage,
                ),
              ],
            ),
          ),
          if (state.filterDrawerOpen)
            Positioned.fill(
              child: BillsFilterDrawer(
                state: state,
                onToggleMethod: cubit.toggleMethodFilter,
                onStatusChanged: cubit.setStatusFilter,
                onClear: cubit.clearFilters,
                onClose: () => cubit.setFilterDrawerOpen(open: false),
              ),
            ),
          if (selectedBill != null)
            Positioned.fill(
              child: ReceiptModal(
                shop: state.posState.shop,
                bill: selectedBill,
                fresh: false,
                staff: staff,
                onDone: () => cubit.selectBill(null),
                onVoid: (reason) =>
                    cubit.voidBillById(staff: staff, reason: reason),
              ),
            ),
        ],
      ),
    );
  }
}
