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

/// Builds the contextual Topbar controls for `/stock` (date selector on
/// count/purchase/expense tabs; grid/list/filter controls on balance tab).
List<Widget> buildStockHeaderActions(
  StockCubit cubit,
  StockCountBloc countBloc,
) {
  final state = cubit.state;
  if (state.activeTab != 'balance') {
    return <Widget>[
      SizedBox(
        width: 210,
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
      ),
    ];
  }
  return <Widget>[
    Btn(
      key: const ValueKey('stock-view-grid-btn'),
      icon: 'grid',
      kind: state.balanceViewMode == 'grid' ? BtnKind.primary : BtnKind.normal,
      onPressed: () => cubit.setBalanceViewMode('grid'),
    ),
    Btn(
      key: const ValueKey('stock-view-list-btn'),
      icon: 'list',
      kind: state.balanceViewMode == 'list' ? BtnKind.primary : BtnKind.normal,
      onPressed: () => cubit.setBalanceViewMode('list'),
    ),
    Btn(
      key: const ValueKey('stock-filter-btn'),
      icon: 'filter',
      kind: state.activeFilterCount > 0 ? BtnKind.primary : BtnKind.normal,
      label: state.activeFilterCount > 0
          ? 'ตัวกรอง (${state.activeFilterCount})'
          : 'ตัวกรอง',
      onPressed: () => cubit.setFilterDrawerOpen(open: true),
    ),
  ];
}

List<Widget> _buildTabContextPills(
  StockState state,
  StockCountState countState,
) => switch (state.activeTab) {
  'count' => <Widget>[
    Pill(
      tone: countState.isClosed ? PillTone.green : PillTone.orange,
      label: countState.isClosed
          ? 'ปิดยอดแล้ว · แก้ตัวเลขแล้วกดบันทึกได้'
          : 'แตะรายการแล้วป้อนจำนวน · Enter = รายการถัดไป',
    ),
    if (countState.skippedWeeklyCount > 0)
      Pill(
        label:
            'นับรายสัปดาห์ '
            '(วัน${kDowNames[countState.posState.shop.weeklyCountDow % 7]}) '
            '${countState.skippedWeeklyCount} รายการ ใช้ค่าประมาณ',
      ),
  ],
  'purchase' => const <Widget>[
    Pill(
      tone: PillTone.orange,
      label: 'แตะ "เหมือนครั้งก่อน" เพื่อคัดลอกบิลล่าสุด แล้วแก้เฉพาะตัวเลข',
    ),
  ],
  'expense' => const <Widget>[
    Pill(
      tone: PillTone.orange,
      label: 'ค่าใช้จ่ายรายวันไม่เข้าสต็อก · ใช้หักคำนวณกำไรสุทธิประจำวัน',
    ),
  ],
  _ => const <Widget>[
    Pill(
      tone: PillTone.orange,
      label: 'คงเหลือ = นับล่าสุด + ซื้อเข้า · แนะนำสั่งซื้อ = ควรมี − คงเหลือ',
    ),
  ],
};

/// Main `/stock` screen (`StockView` in `prototype/index.html` &
/// `design/figma/supply_list.png`, `supply_grid.png`,
/// `filter_history_supply.png`).
class StockPage extends StatelessWidget {
  const new({required this.staff, super.key});

  final StaffMember staff;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StockCubit>().state;
    final cubit = context.read<StockCubit>();
    final countBloc = context.read<StockCountBloc>();
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW <= AppDimensions.mobileBp;
    final hPad = AppDimensions.pagePadding(screenW);

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
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: context.tokens.line),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    hPad,
                    AppDimensions.space3_5,
                    hPad,
                    AppDimensions.space3,
                  ),
                  child: isMobile
                      ? Wrap(
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
                            Wrap(
                              spacing: AppDimensions.space2,
                              runSpacing: AppDimensions.space2,
                              children: buildStockHeaderActions(
                                cubit,
                                countBloc,
                              ),
                            ),
                          ],
                        )
                      : Row(
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
                            const SizedBox(width: AppDimensions.space3),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final (i, w)
                                          in _buildTabContextPills(
                                            state,
                                            context
                                                .watch<StockCountBloc>()
                                                .state,
                                          ).indexed) ...[
                                        if (i > 0)
                                          const SizedBox(
                                            width: AppDimensions.space2,
                                          ),
                                        w,
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
