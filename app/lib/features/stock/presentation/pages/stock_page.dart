import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/bloc/stock_count_bloc.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:app/features/stock/presentation/widgets/stock_balance_tab.dart';
import 'package:app/features/stock/presentation/widgets/stock_count_tab.dart';
import 'package:app/features/stock/presentation/widgets/stock_expense_tab.dart';
import 'package:app/features/stock/presentation/widgets/stock_filter_drawer.dart';
import 'package:app/features/stock/presentation/widgets/stock_purchase_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Main `/stock` screen (`StockView` in `prototype/index.html` &
/// `design/figma/supply_list.png`, `supply_grid.png`,
/// `filter_history_supply.png`).
class StockPage extends StatelessWidget {
  const new({required this.staff, super.key});

  final StaffMember staff;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = context.watch<StockCubit>().state;
    final cubit = context.read<StockCubit>();
    final countBloc = context.read<StockCountBloc>();

    return MultiBlocListener(
      listeners: [
        BlocListener<StockCountBloc, StockCountState>(
          listenWhen: (prev, curr) =>
              curr.toastMessage.isNotEmpty &&
              curr.toastMessage != prev.toastMessage,
          listener: (context, s) {
            showAppToast(context, s.toastMessage);
            context.read<StockCountBloc>().add(const StockCountToastCleared());
          },
        ),
        BlocListener<StockCubit, StockState>(
          listenWhen: (prev, curr) =>
              curr.toastMessage.isNotEmpty &&
              curr.toastMessage != prev.toastMessage,
          listener: (context, s) {
            showAppToast(context, s.toastMessage);
            context.read<StockCubit>().clearToast();
          },
        ),
      ],
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.space6,
                  AppDimensions.space4,
                  AppDimensions.space6,
                  AppDimensions.space3,
                ),
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
                child: Wrap(
                  spacing: AppDimensions.space3,
                  runSpacing: AppDimensions.space2,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Tabs<String>(
                      key: const ValueKey('stock-tabs'),
                      value: state.activeTab,
                      onChanged: cubit.setTab,
                      items: const [
                        TabItem(value: 'count', label: 'นับของเหลือ'),
                        TabItem(value: 'purchase', label: 'ซื้อของ'),
                        TabItem(value: 'expense', label: 'ค่าใช้จ่าย'),
                        TabItem(value: 'balance', label: 'คงเหลือ'),
                      ],
                    ),
                    if (state.activeTab != 'balance')
                      SizedBox(
                        width: 220,
                        child: Dropdown<String>(
                          key: const ValueKey('stock-date-dropdown'),
                          value: state.selectedDate,
                          onChanged: (d) {
                            cubit.setDate(d);
                            countBloc.add(StockCountDateChanged(d));
                          },
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
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Btn(
                            key: const ValueKey('stock-view-grid-btn'),
                            icon: 'grid',
                            kind: state.balanceViewMode == 'grid'
                                ? BtnKind.primary
                                : BtnKind.normal,
                            onPressed: () => cubit.setBalanceViewMode('grid'),
                          ),
                          const SizedBox(width: AppDimensions.space2),
                          Btn(
                            key: const ValueKey('stock-view-list-btn'),
                            icon: 'list',
                            kind: state.balanceViewMode == 'list'
                                ? BtnKind.primary
                                : BtnKind.normal,
                            onPressed: () => cubit.setBalanceViewMode('list'),
                          ),
                          const SizedBox(width: AppDimensions.space2),
                          Btn(
                            key: const ValueKey('stock-filter-btn'),
                            icon: 'filter',
                            kind: state.activeFilterCount > 0
                                ? BtnKind.primary
                                : BtnKind.normal,
                            label: state.activeFilterCount > 0
                                ? 'ตัวกรอง (${state.activeFilterCount})'
                                : 'ตัวกรอง',
                            onPressed: () =>
                                cubit.setFilterDrawerOpen(open: true),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Expanded(
                child: switch (state.activeTab) {
                  'count' => StockCountTab(staff: staff),
                  'purchase' => StockPurchaseTab(staff: staff),
                  'expense' => StockExpenseTab(staff: staff),
                  _ => const StockBalanceTab(),
                },
              ),
            ],
          ),
          if (state.filterDrawerOpen)
            Positioned.fill(
              child: StockFilterDrawer(
                state: state,
                onToggleLocation: cubit.toggleLocationFilter,
                onStatusChanged: cubit.setStatusFilter,
                onClear: cubit.clearFilters,
                onClose: () => cubit.setFilterDrawerOpen(open: false),
              ),
            ),
        ],
      ),
    );
  }
}
