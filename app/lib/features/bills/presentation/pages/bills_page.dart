import 'package:app/core/sync/sync_widgets.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/bills/presentation/widgets/bills_filter_drawer.dart';
import 'package:app/features/bills/presentation/widgets/reissue_bill_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Builds the date dropdown and filter button for `/bills`, shown in the
/// unified Topbar on tablet/desktop and inline on mobile (`<= 760px`).
List<Widget> buildBillsHeaderActions(BillsCubit cubit) {
  final state = cubit.state;
  return <Widget>[
    SizedBox(
      width: 210,
      child: Dropdown<String>(
        key: const ValueKey('bills-date-dropdown'),
        value: state.selectedDate,
        onChanged: cubit.setDate,
        options: [
          for (final d in state.availableDates)
            DropdownOption<String>(
              value: d,
              label: d == state.todayDate ? 'วันนี้ · ${thDate(d)}' : thDate(d),
            ),
        ],
      ),
    ),
    Btn(
      key: const ValueKey('bills-filter-btn'),
      icon: 'filter',
      kind: state.activeFilterCount > 0 ? BtnKind.primary : BtnKind.normal,
      label: state.activeFilterCount > 0
          ? 'ตัวกรอง (${state.activeFilterCount})'
          : 'ตัวกรอง',
      onPressed: () => cubit.setFilterDrawerOpen(open: true),
    ),
  ];
}

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
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW <= AppDimensions.mobileBp;
    final pagePad = AppDimensions.pagePadding(screenW);
    final voided = state.voidedCount > 0;
    const tabFeat = [FontFeature.tabularFigures()];
    final tabular = tt.bodyMedium?.copyWith(
      color: t.ink,
      fontFeatures: tabFeat,
    );
    final boldInk = tabular?.copyWith(fontWeight: FontWeight.w700);
    TextStyle? rowBold(BillRecord b) =>
        boldInk?.copyWith(color: b.voided ? t.muted : t.ink);

    return BlocListener<BillsCubit, BillsState>(
      listenWhen: (p, c) =>
          c.toastMessage.isNotEmpty && c.toastMessage != p.toastMessage,
      listener: (context, s) {
        showAppToast(context, s.toastMessage);
        context.read<BillsCubit>().clearToast();
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(pagePad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isMobile) ...[
                  Wrap(
                    spacing: AppDimensions.space2_5,
                    runSpacing: AppDimensions.space2,
                    children: buildBillsHeaderActions(cubit),
                  ),
                  const SizedBox(height: AppDimensions.space4),
                ],
                StatsGroup(
                  key: const ValueKey('bills-stats-group'),
                  children: [
                    Stat(
                      label: 'ยอดขาย (${thDate(state.selectedDate)})',
                      value: bahtSmart(state.totalSales),
                      sub: '${state.okBills.length} บิลที่ชำระสำเร็จ',
                      tone: StatTone.green,
                    ),
                    if (state.totalVat > 0)
                      Stat(
                        label: 'ภาษีขายรวม (VAT)',
                        value: baht(state.totalVat, 2),
                        sub: 'มูลค่าก่อนภาษี ${baht(state.totalPreVat, 2)}',
                      ),
                    Stat(
                      label: 'จำนวนบิล',
                      value: '${state.okBills.length}',
                      sub: voided
                          ? 'ยกเลิก ${state.voidedCount} บิล'
                          : 'ไม่มีบิลยกเลิก',
                      tone: voided ? StatTone.red : StatTone.neutral,
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
                  BillsMethodSummaryBar(salesByMethod: state.salesByMethod),
                ],
                if (state.activeFilterCount > 0) ...[
                  const SizedBox(height: AppDimensions.space3),
                  BillsActiveFiltersRow(
                    state: state,
                    onClear: cubit.clearFilters,
                  ),
                ],
                const SizedBox(height: AppDimensions.space4),
                PosDataTable<BillRecord>(
                  rows: state.pagedBills,
                  onRowTap: (b) => cubit.selectBill(b.id),
                  empty: Empty(
                    title: 'ไม่มีบิล',
                    text: state.olderFailed
                        ? 'ต้องออนไลน์เพื่อดูบิลย้อนหลัง'
                        : 'ยังไม่มีรายการขายตามเงื่อนไขที่เลือก',
                  ),
                  columns: [
                    DataTableCol<BillRecord>(
                      key: 'no',
                      label: 'เลขที่',
                      flex: 2,
                      cellBuilder: (_, b) => Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: AppDimensions.space1_5,
                        children: [
                          Flexible(
                            child: Text(
                              b.no,
                              key: ValueKey('bill-row-no-${b.id}'),
                              overflow: TextOverflow.ellipsis,
                              style: rowBold(b),
                            ),
                          ),
                          if (b.isFullInvoice)
                            const Pill(label: 'เต็มรูป', tone: PillTone.green),
                          if (b.voided)
                            const Pill(label: 'ยกเลิก', tone: PillTone.red),
                          BillSyncBadge(billId: b.id),
                        ],
                      ),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'at',
                      label: 'เวลา',
                      cellBuilder: (_, b) => Text(thTime(b.at), style: tabular),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'table',
                      label: 'โต๊ะ',
                      cellBuilder: (_, b) => Text(
                        b.tableName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rowBold(b),
                      ),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'heads',
                      label: 'ลูกค้า',
                      cellBuilder: (_, b) => Text(
                        '${b.heads.a + b.heads.c + b.heads.f} คน',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tabular,
                      ),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'method',
                      label: 'ชำระโดย',
                      flex: 2,
                      cellBuilder: (_, b) => Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: AppDimensions.space1_5,
                        children: [
                          AppIcon(
                            billsMethodIcon(b.methodType),
                            size: 14,
                            color: t.muted,
                          ),
                          Flexible(
                            child: Text(
                              (b.bankAccountInfo ?? '').isNotEmpty
                                  ? '${b.methodName} · ${b.bankAccountInfo}'
                                  : b.methodName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'staff',
                      label: 'แคชเชียร์',
                      flex: 2,
                      cellBuilder: (_, b) => Text(
                        b.staffName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataTableCol<BillRecord>(
                      key: 'total',
                      label: 'ยอด',
                      flex: 2,
                      align: ColAlign.right,
                      cellBuilder: (_, b) => Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        spacing: AppDimensions.space1_5,
                        children: [
                          Text(
                            baht(b.total, 2),
                            textAlign: TextAlign.right,
                            style: rowBold(b)?.copyWith(
                              decoration: b.voided
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          Text('›', style: tabular?.copyWith(color: t.muted)),
                        ],
                      ),
                    ),
                  ],
                  footerCells: state.pagedBills.isEmpty
                      ? null
                      : [
                          Text(
                            'รวม (${state.okBills.length} บิล)',
                            style: boldInk,
                          ),
                          const SizedBox.shrink(),
                          const SizedBox.shrink(),
                          Text(
                            '${state.totalPaidHeads + state.totalFreeHeads} คน',
                            style: boldInk,
                          ),
                          const SizedBox.shrink(),
                          const SizedBox.shrink(),
                          Text(
                            baht(state.totalSales, 2),
                            textAlign: TextAlign.right,
                            style: boldInk?.copyWith(color: t.successInk),
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
              child: billReceiptOverlay(context, cubit, selectedBill, staff),
            ),
        ],
      ),
    );
  }
}
