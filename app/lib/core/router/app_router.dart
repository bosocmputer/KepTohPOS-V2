import 'dart:async';

import 'package:app/core/layout/app_shell.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/dev_components_page.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/auth/presentation/pages/login_page.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/bills/presentation/pages/bills_page.dart';
import 'package:app/features/sale/presentation/pages/sale_page.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:app/features/shift/presentation/pages/shift_page.dart';
import 'package:app/features/stock/presentation/bloc/stock_count_bloc.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:app/features/stock/presentation/pages/stock_page.dart';
import 'package:app/features/tables/presentation/pages/tables_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class _StreamRefreshListenable extends ChangeNotifier {
  new(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

/// Creates the application [GoRouter] with routes matching `VIEWS`.
GoRouter createAppRouter({
  String initialLocation = '/tables',
  AuthCubit? authCubit,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: authCubit != null
      ? _StreamRefreshListenable(authCubit.stream)
      : null,
  redirect: (context, state) {
    if (authCubit == null) return null;
    final me = authCubit.state.currentStaff;
    final loc = state.matchedLocation;
    if (me == null) {
      return (loc != '/login' && loc != '/dev/components') ? '/login' : null;
    }
    if (loc == '/login') return '/tables';
    final viewId = loc.startsWith('/') ? loc.substring(1) : loc;
    final rootViewId = viewId.split('/').first;
    if (viewId.isNotEmpty &&
        viewId != 'dev/components' &&
        !canAccessViewId(me.role, rootViewId)) {
      return '/tables';
    }
    return null;
  },
  routes: <RouteBase>[
    GoRoute(path: '/', redirect: (_, _) => '/tables'),
    GoRoute(
      path: '/login',
      builder: (context, state) =>
          LoginPage(onLoggedIn: () => context.go('/tables')),
    ),
    GoRoute(
      path: '/tables/:tableId',
      builder: (context, state) => ShellPlaceholderPage(
        viewSpec: kAppViews.first,
        saleTableId: state.pathParameters['tableId'],
      ),
    ),
    for (final view in kAppViews)
      GoRoute(
        path: '/${view.id}',
        builder: (context, state) => ShellPlaceholderPage(viewSpec: view),
      ),
    if (kDebugMode)
      GoRoute(
        path: '/dev/components',
        builder: (context, state) => const DevComponentsPage(),
      ),
  ],
);

/// Screen wrapper for each `VIEWS` route inside [AppShell].
class ShellPlaceholderPage extends StatefulWidget {
  const new({
    required this.viewSpec,
    super.key,
    this.staffRole = 'owner',
    this.initialDrawerOpen = false,
    this.saleTableId,
  });

  final AppViewSpec viewSpec;
  final String staffRole;
  final bool initialDrawerOpen;
  final String? saleTableId;

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
  Widget build(BuildContext context) {
    final repo = _maybe<PosRepository>(context, watch: false);
    final existingStockCubit = _maybe<StockCubit>(context, watch: false);
    final existingStockBloc = _maybe<StockCountBloc>(context, watch: false);
    if (widget.viewSpec.id == 'stock' &&
        repo != null &&
        (existingStockCubit == null || existingStockBloc == null)) {
      return MultiBlocProvider(
        key: const ValueKey('stock-scope'),
        providers: [
          if (existingStockCubit == null)
            BlocProvider<StockCubit>(create: (_) => StockCubit(repo)),
          if (existingStockBloc == null)
            BlocProvider<StockCountBloc>(
              create: (_) => StockCountBloc(repository: repo),
            ),
        ],
        child: Builder(builder: _buildShell),
      );
    }
    return _buildShell(context);
  }

  Widget _buildShell(BuildContext context) {
    final tokens = context.tokens;
    final authCubit = _maybe<AuthCubit>(context);
    final shiftBloc = _maybe<ShiftBloc>(context);
    final tablesCubit = _maybe<TablesCubit>(context);
    final billsCubit = _maybe<BillsCubit>(context);
    final stockCubit = _maybe<StockCubit>(context);
    final existingSaleBloc = _maybe<SaleBloc>(context, watch: false);
    final repo = _maybe<PosRepository>(context, watch: false);
    final activeShift = shiftBloc?.state.activeShift;
    final me =
        authCubit?.state.currentStaff ??
        StaffMember(
          id: 'st1',
          name: 'พี่ต้อม (เจ้าของร้าน)',
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
        widget.viewSpec.id == 'tables' &&
        widget.saleTableId != null &&
        (existingSaleBloc != null || repo != null);
    final isTablesView =
        !isSaleView && widget.viewSpec.id == 'tables' && tablesCubit != null;
    final isBillsView =
        widget.viewSpec.id == 'bills' && (billsCubit != null || repo != null);
    final isStockView = widget.viewSpec.id == 'stock' && stockCubit != null;

    final Widget body;
    if (isSaleView) {
      final salePage = SalePage(
        staff: me,
        onBackToTables: () => context.go('/tables'),
        onSelectTable: (id) => context.go('/tables/$id'),
        onRequestOpenShift: () => setState(() => _manualOpenShiftModal = true),
      );
      body = existingSaleBloc != null
          ? salePage
          : BlocProvider<SaleBloc>(
              key: ValueKey('sale-bloc-${widget.saleTableId}'),
              create: (_) =>
                  SaleBloc(repo!, initialTableId: widget.saleTableId!),
              child: salePage,
            );
    } else if (isTablesView) {
      body = TablesPage(
        onSelectTable: (id) => context.go('/tables/$id'),
        onRequestOpenShift: () => setState(() => _manualOpenShiftModal = true),
        onGoSetupTables: () => context.go('/setup'),
      );
    } else if (isBillsView) {
      final billsPage = BillsPage(staff: me);
      body = billsCubit != null
          ? billsPage
          : BlocProvider<BillsCubit>(
              create: (_) => BillsCubit(repo!),
              child: billsPage,
            );
    } else if (isStockView) {
      body = StockPage(staff: me);
    } else if (widget.viewSpec.id == 'shift' && shiftBloc != null) {
      body = ShiftPage(
        staffId: me.id,
        staffName: me.name,
        onGoTables: () => context.go('/tables'),
      );
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: widget.viewSpec.title,
              desc: 'ร้านหมูกระทะ เก็บโต๊ะ',
            ),
            if (widget.viewSpec.id == 'setup') ...[
              const SizedBox(height: AppDimensions.space5),
              const _SetupThemeSection(),
            ],
            const SizedBox(height: AppDimensions.space5),
            Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppDimensions.r),
                border: Border.all(color: tokens.line),
              ),
              child: Empty(
                title: widget.viewSpec.title,
                text:
                    'หน้าจอ ${widget.viewSpec.label} '
                    '(เตรียมเชื่อมข้อมูลในขั้นถัดไป)',
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        AppShell(
          activeViewId: widget.viewSpec.id,
          pageTitle: widget.viewSpec.title,
          staffName: me.name,
          staffRole: me.role,
          shiftOpenTimeText: shiftTimeText,
          shiftStaffName: shiftStaffName,
          initialDrawerOpen: widget.initialDrawerOpen,
          delegateDesktopHeader: isSaleView,
          headerActions: <Widget>[
            if (isTablesView)
              Btn(
                key: const ValueKey('topbar-open-table-btn'),
                kind: BtnKind.primary,
                label: 'เปิดโต๊ะ',
                onPressed: () {
                  final s = tablesCubit.state.posState;
                  final free = s.tables.where(
                    (t) => !s.openTables.containsKey(t.id),
                  );
                  final id = free.isNotEmpty
                      ? free.first.id
                      : (s.tables.isNotEmpty ? s.tables.first.id : 't1');
                  context.go('/tables/$id');
                },
              ),
          ],
          searchQuery: isTablesView
              ? tablesCubit.state.searchQuery
              : isBillsView && billsCubit != null
              ? billsCubit.state.searchQuery
              : isStockView
              ? stockCubit.state.searchQuery
              : '',
          searchPlaceholder: isTablesView
              ? 'ค้นหาชื่อโต๊ะ'
              : isBillsView
              ? 'ค้นหาเลขที่บิล โต๊ะ ช่องทาง แคชเชียร์'
              : isStockView
              ? 'ค้นหาวัตถุดิบ แหล่งซื้อ สถานที่เก็บ'
              : 'ค้นหา',
          onSearchChanged: isTablesView
              ? tablesCubit.setSearchQuery
              : isBillsView && billsCubit != null
              ? billsCubit.setSearchQuery
              : isStockView
              ? stockCubit.setSearchQuery
              : null,
          onNavigate: (viewId) => viewId == 'dev/components'
              ? unawaited(context.push('/dev/components'))
              : context.go('/$viewId'),
          onShiftAction: () => activeShift != null
              ? context.go('/shift')
              : setState(() => _manualOpenShiftModal = true),
          onLogout: () {
            authCubit?.logout();
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

class _SetupThemeSection extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final mode = context.watch<ThemeCubit>().state.mode;
    final cubit = context.read<ThemeCubit>();
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.r),
        border: Border.all(color: t.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ธีมและการแสดงผล', style: tt.titleLarge),
              Text('เลือกโหมดสว่าง มืด หรือตามเครื่อง', style: tt.bodySmall),
            ],
          ),
          Row(
            children: [
              for (final m in AppThemeMode.values)
                Padding(
                  padding: const EdgeInsets.only(left: AppDimensions.space2),
                  child: Btn(
                    key: ValueKey('setup-mode-${m.name}'),
                    label: m.label,
                    size: BtnSize.sm,
                    kind: mode == m ? BtnKind.primary : BtnKind.normal,
                    onPressed: () => cubit.setMode(m),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
