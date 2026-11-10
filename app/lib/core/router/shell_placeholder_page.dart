import 'dart:async';

import 'package:app/core/layout/app_shell.dart';
import 'package:app/core/router/app_router.dart';
import 'package:app/core/sync/sync_widgets.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/bills/presentation/pages/bills_page.dart';
import 'package:app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:app/features/reports/presentation/pages/reports_page.dart';
import 'package:app/features/sale/presentation/pages/sale_page.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:app/features/stock/presentation/bloc/stock_count_bloc.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:app/features/tables/presentation/pages/tables_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Screen wrapper for each `VIEWS` route inside [AppShell].
class ShellPlaceholderPage extends StatefulWidget {
  const new({
    required this.viewSpec,
    super.key,
    this.staffRole = 'owner',
    this.initialDrawerOpen = false,
    this.saleTableId,
    this.billsDate,
    this.now,
  });

  final AppViewSpec viewSpec;
  final String staffRole;
  final bool initialDrawerOpen;
  final String? saleTableId;
  final String? billsDate;
  final DateTime? now;

  @override
  State<ShellPlaceholderPage> createState() => _ShellPlaceholderPageState();
}

class _ShellPlaceholderPageState extends State<ShellPlaceholderPage> {
  bool _manualOpenShiftModal = false;

  T? _maybe<T>(BuildContext context, {bool watch = true}) {
    try {
      return watch ? context.watch<T>() : context.read<T>();
    } on Object {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncBillsDate();
  }

  @override
  void didUpdateWidget(covariant ShellPlaceholderPage old) {
    super.didUpdateWidget(old);
    if (widget.billsDate != old.billsDate ||
        widget.viewSpec.id != old.viewSpec.id) {
      _syncBillsDate();
    }
  }

  void _syncBillsDate() {
    final targetDate = widget.billsDate;
    if (widget.viewSpec.id != 'bills' || targetDate == null) return;
    final cubit = _maybe<BillsCubit>(context, watch: false);
    if (cubit != null && cubit.state.selectedDate != targetDate) {
      cubit.setDate(targetDate);
    }
  }

  @override
  Widget build(BuildContext context) => wrapViewScope(
    viewId: widget.viewSpec.id,
    repo: _maybe<PosRepository>(context, watch: false),
    now: widget.now,
    billsDate: widget.billsDate,
    existingBills: _maybe<BillsCubit>(context, watch: false),
    existingStockCubit: _maybe<StockCubit>(context, watch: false),
    existingStockBloc: _maybe<StockCountBloc>(context, watch: false),
    existingDash: _maybe<DashboardCubit>(context, watch: false),
    existingRep: _maybe<ReportsCubit>(context, watch: false),
    existingSetup: _maybe<SetupCubit>(context, watch: false),
    builder: _buildShell,
  );

  Widget _buildShell(BuildContext context) {
    final tokens = context.tokens;
    final viewId = widget.viewSpec.id;
    T? m<T>({bool w = true}) => _maybe<T>(context, watch: w);
    final authCubit = m<AuthCubit>();
    final shiftBloc = m<ShiftBloc>();
    final tablesCubit = m<TablesCubit>(w: viewId == 'tables');
    final billsCubit = m<BillsCubit>(w: viewId == 'bills');
    final stockCubit = m<StockCubit>(w: viewId == 'stock');
    final stockCountBloc = m<StockCountBloc>(w: viewId == 'stock');
    final dashCubit = m<DashboardCubit>(w: viewId == 'dashboard');
    final repCubit = m<ReportsCubit>(w: viewId == 'reports');
    final setupCubit = m<SetupCubit>(w: viewId == 'setup');
    final existingSaleBloc = m<SaleBloc>(w: false);
    final repo = m<PosRepository>(w: false);
    final activeShift = shiftBloc?.state.activeShift;
    final me =
        authCubit?.state.currentStaff ??
        StaffMember(
          id: 'st1',
          name: 'พี่ต้อม',
          role: widget.staffRole,
          pin: '1111',
        );
    final shiftTimeText = shiftBloc != null
        ? (activeShift != null ? thTime(activeShift.openedAt) : null)
        : '09:00';
    final shiftStaffName = shiftBloc != null && activeShift != null
        ? shiftBloc.state.staffNameOf(activeShift.staffId)
        : me.name;
    final showOpenShiftModal =
        shiftBloc != null &&
        activeShift == null &&
        ((authCubit?.state.shouldPromptOpenShift ?? false) ||
            _manualOpenShiftModal);

    final isSaleView =
        viewId == 'tables' &&
        widget.saleTableId != null &&
        (existingSaleBloc != null || repo != null);
    final isTablesView =
        !isSaleView && viewId == 'tables' && tablesCubit != null;
    final isBillsView =
        viewId == 'bills' && (billsCubit != null || repo != null);
    final isStockView = viewId == 'stock' && stockCubit != null;
    final isSetupCatalog =
        viewId == 'setup' &&
        setupCubit?.state.itemCountOf(setupCubit.state.activeTab) != null;

    final Widget body;
    if (isSaleView) {
      final page = SalePage(
        staff: me,
        onBackToTables: () => context.go('/tables'),
        onSelectTable: (id) => context.go('/tables/$id'),
        onRequestOpenShift: () => setState(() => _manualOpenShiftModal = true),
      );
      body = existingSaleBloc != null
          ? page
          : BlocProvider(
              key: ValueKey('sale-bloc-${widget.saleTableId}'),
              create: (_) => SaleBloc(
                repo!,
                initialTableId: widget.saleTableId!,
                now: widget.now,
              ),
              child: page,
            );
    } else if (isTablesView) {
      body = TablesPage(
        onSelectTable: (id) => context.go('/tables/$id'),
        onRequestOpenShift: () => setState(() => _manualOpenShiftModal = true),
        onGoSetupTables: () => context.go('/setup'),
      );
    } else if (isBillsView) {
      final page = BillsPage(staff: me);
      body = billsCubit != null
          ? page
          : BlocProvider(
              create: (_) => BillsCubit(
                repo!,
                now: widget.now,
                initialDate: widget.billsDate,
              ),
              child: page,
            );
    } else {
      body = buildAnalyticsOrPlaceholderBody(
        context,
        viewSpec: widget.viewSpec,
        me: me,
        tokens: tokens,
        stockCubit: stockCubit,
        shiftBloc: shiftBloc,
        billsCubit: billsCubit,
        existingDash: dashCubit,
        existingRep: repCubit,
        existingSetup: setupCubit,
      );
    }

    return Stack(
      children: [
        AppShell(
          activeViewId: viewId,
          pageTitle: widget.viewSpec.title,
          staffName: me.name,
          staffRole: me.role,
          seesCosts: me.seesCosts,
          shiftOpenTimeText: shiftTimeText,
          shiftStaffName: shiftStaffName,
          initialDrawerOpen: widget.initialDrawerOpen,
          delegateDesktopHeader: isSaleView,
          headerActions: buildViewHeaderActions(
            context,
            viewId: viewId,
            isTablesView: isTablesView,
            tablesCubit: tablesCubit,
            billsCubit: billsCubit,
            stockCubit: stockCubit,
            stockCountBloc: stockCountBloc,
            dashCubit: dashCubit,
            repCubit: repCubit,
          ),
          searchQuery: isTablesView
              ? tablesCubit.state.searchQuery
              : isBillsView && billsCubit != null
              ? billsCubit.state.searchQuery
              : isStockView
              ? stockCubit.state.searchQuery
              : isSetupCatalog
              ? (setupCubit?.state.searchQuery ?? '')
              : '',
          searchPlaceholder: isTablesView
              ? 'ค้นหาชื่อโต๊ะ'
              : isBillsView
              ? 'ค้นหาเลขที่บิล โต๊ะ ช่องทาง แคชเชียร์'
              : isStockView
              ? 'ค้นหาวัตถุดิบ แหล่งซื้อ สถานที่เก็บ'
              : isSetupCatalog
              ? 'ค้นหารายการในหมวดนี้'
              : 'ค้นหา',
          onSearchChanged: isTablesView
              ? tablesCubit.setSearchQuery
              : isBillsView && billsCubit != null
              ? billsCubit.setSearchQuery
              : isStockView
              ? stockCubit.setSearchQuery
              : isSetupCatalog
              ? setupCubit?.setSearchQuery
              : null,
          onNavigate: (id) => id == 'dev/components'
              ? unawaited(context.push('/dev/components'))
              : context.go('/$id'),
          onShiftAction: () => activeShift != null
              ? context.go('/shift')
              : setState(() => _manualOpenShiftModal = true),
          onLogout: () async {
            final go = await confirmWithPendingSync(
              context,
              action: 'ออกจากระบบ',
            );
            if (!go || !context.mounted) return;
            unawaited(authCubit?.logout());
            context.go('/login');
          },
          child: body,
        ),
        if (showOpenShiftModal)
          OpenShiftModal(
            staffId: me.id,
            staffName: me.name,
            onClose: () {
              setState(() => _manualOpenShiftModal = false);
              authCubit?.dismissOpenShiftPrompt();
            },
          ),
      ],
    );
  }
}
