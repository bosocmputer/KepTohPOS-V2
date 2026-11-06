import 'dart:async';

import 'package:app/core/layout/app_shell.dart';
import 'package:app/core/router/app_router.dart';
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
    final authCubit = _maybe<AuthCubit>(context);
    final shiftBloc = _maybe<ShiftBloc>(context);
    final tablesCubit = _maybe<TablesCubit>(context);
    final billsCubit = _maybe<BillsCubit>(context);
    final stockCubit = _maybe<StockCubit>(context);
    final stockCountBloc = _maybe<StockCountBloc>(context);
    final dashCubit = _maybe<DashboardCubit>(context);
    final repCubit = _maybe<ReportsCubit>(context);
    final setupCubit = _maybe<SetupCubit>(context);
    final existingSaleBloc = _maybe<SaleBloc>(context, watch: false);
    final repo = _maybe<PosRepository>(context, watch: false);
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

    final viewId = widget.viewSpec.id;
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

    return Stack(
      children: [
        AppShell(
          activeViewId: viewId,
          pageTitle: widget.viewSpec.title,
          staffName: me.name,
          staffRole: me.role,
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
          onLogout: () {
            authCubit?.logout();
            context.go('/login');
          },
          child: _buildBody(
            context,
            viewId: viewId,
            me: me,
            repo: repo,
            existingSaleBloc: existingSaleBloc,
            tablesCubit: tablesCubit,
            billsCubit: billsCubit,
            stockCubit: stockCubit,
            shiftBloc: shiftBloc,
            dashCubit: dashCubit,
            repCubit: repCubit,
            setupCubit: setupCubit,
            tokens: tokens,
          ),
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

  Widget _buildBody(
    BuildContext context, {
    required String viewId,
    required StaffMember me,
    required PosRepository? repo,
    required SaleBloc? existingSaleBloc,
    required TablesCubit? tablesCubit,
    required BillsCubit? billsCubit,
    required StockCubit? stockCubit,
    required ShiftBloc? shiftBloc,
    required DashboardCubit? dashCubit,
    required ReportsCubit? repCubit,
    required SetupCubit? setupCubit,
    required AppTokens tokens,
  }) {
    if (viewId == 'tables' &&
        widget.saleTableId != null &&
        (existingSaleBloc != null || repo != null)) {
      final page = SalePage(
        staff: me,
        onBackToTables: () => context.go('/tables'),
        onSelectTable: (id) => context.go('/tables/$id'),
        onRequestOpenShift: () => setState(() => _manualOpenShiftModal = true),
      );
      return existingSaleBloc != null
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
    }
    if (viewId == 'tables' && tablesCubit != null) {
      return TablesPage(
        onSelectTable: (id) => context.go('/tables/$id'),
        onRequestOpenShift: () => setState(() => _manualOpenShiftModal = true),
        onGoSetupTables: () => context.go('/setup'),
      );
    }
    if (viewId == 'bills' && (billsCubit != null || repo != null)) {
      final page = BillsPage(staff: me);
      if (billsCubit != null) return page;
      final d = widget.billsDate;
      return BlocProvider(
        create: (_) => BillsCubit(repo!, now: widget.now, initialDate: d),
        child: page,
      );
    }
    return buildAnalyticsOrPlaceholderBody(
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
}
