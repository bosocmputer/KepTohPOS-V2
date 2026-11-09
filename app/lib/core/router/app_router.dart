
import 'dart:async';

import 'package:app/core/diagnostics/e2e_trace.dart';
import 'package:app/core/router/shell_placeholder_page.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/dev_components_page.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/auth/presentation/pages/login_page.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/bills/presentation/pages/bills_page.dart';
import 'package:app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:app/features/reports/presentation/pages/reports_page.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:app/features/setup/presentation/pages/setup_page.dart';
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

export 'package:app/core/router/shell_placeholder_page.dart';
export 'package:app/features/setup/presentation/pages/setup_page.dart'
    show SetupPage, SetupThemeSection;
export 'package:app/features/shift/presentation/pages/shift_page.dart'
    show OpenShiftModal;

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
  DateTime? now,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: authCubit != null
      ? _StreamRefreshListenable(authCubit.stream)
      : null,
  redirect: (context, state) {
    if (authCubit == null) return null;
    final me = authCubit.state.currentStaff;
    final loc = state.matchedLocation;
    e2eTrace('router redirect loc=$loc me=${me?.id}');
    if (me == null) {
      return (loc != '/login' && loc != '/dev/components') ? '/login' : null;
    }
    if (loc == '/login') return '/tables';
    final viewId = loc.startsWith('/') ? loc.substring(1) : loc;
    final rootViewId = viewId.split('/').first;
    if (viewId.isNotEmpty &&
        viewId != 'dev/components' &&
        !canAccessViewIdFor(me.role, rootViewId, seesCosts: me.seesCosts)) {
      return '/tables';
    }
    return null;
  },
  routes: <RouteBase>[
    GoRoute(path: '/', redirect: (_, _) => '/tables'),
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginPage(
        onLoggedIn: () {
          e2eTrace('router: go /tables from login');
          context.go('/tables');
        },
      ),
    ),
    GoRoute(
      path: '/tables/:tableId',
      builder: (context, state) => ShellPlaceholderPage(
        viewSpec: kAppViews.first,
        saleTableId: state.pathParameters['tableId'],
        now: now,
      ),
    ),
    for (final view in kAppViews)
      GoRoute(
        path: '/${view.id}',
        builder: (context, state) => ShellPlaceholderPage(
          viewSpec: view,
          billsDate: state.uri.queryParameters['date'],
          now: now,
        ),
      ),
    if (kDebugMode)
      GoRoute(
        path: '/dev/components',
        builder: (context, state) => const DevComponentsPage(),
      ),
  ],
);

/// Wraps [builder] with route-level Cubit/Bloc providers when not already
/// provided above [ShellPlaceholderPage].
Widget wrapViewScope({
  required String viewId,
  required PosRepository? repo,
  required DateTime? now,
  required String? billsDate,
  required BillsCubit? existingBills,
  required StockCubit? existingStockCubit,
  required StockCountBloc? existingStockBloc,
  required DashboardCubit? existingDash,
  required ReportsCubit? existingRep,
  required WidgetBuilder builder,
  SetupCubit? existingSetup,
}) {
  if (repo == null) return Builder(builder: builder);
  final providers = [
    if (viewId == 'bills' && existingBills == null)
      BlocProvider(
        create: (_) => BillsCubit(repo, now: now, initialDate: billsDate),
      ),
    if (viewId == 'stock' && existingStockCubit == null)
      BlocProvider(create: (_) => StockCubit(repo, now: now)),
    if (viewId == 'stock' && existingStockBloc == null)
      BlocProvider(
        create: (_) => StockCountBloc(repository: repo, now: now),
      ),
    if (viewId == 'dashboard' && existingDash == null)
      BlocProvider(create: (_) => DashboardCubit(repo, now: now)),
    if (viewId == 'reports' && existingRep == null)
      BlocProvider(create: (_) => ReportsCubit(repo, now: now)),
    if (viewId == 'setup' && existingSetup == null)
      BlocProvider(create: (_) => SetupCubit(repo, now: now)),
  ];
  if (providers.isEmpty) return Builder(builder: builder);
  return MultiBlocProvider(
    key: ValueKey('$viewId-scope'),
    providers: providers,
    child: Builder(builder: builder),
  );
}

/// Builds contextual Topbar action widgets for the active view.
List<Widget> buildViewHeaderActions(
  BuildContext context, {
  required String viewId,
  required bool isTablesView,
  required TablesCubit? tablesCubit,
  required BillsCubit? billsCubit,
  required StockCubit? stockCubit,
  required StockCountBloc? stockCountBloc,
  required DashboardCubit? dashCubit,
  required ReportsCubit? repCubit,
}) => <Widget>[
  if (isTablesView && tablesCubit != null) ...[
    buildTablesZoneDropdown(tablesCubit, tablesCubit.state),
    Btn(
      key: const ValueKey('topbar-open-table-btn'),
      kind: BtnKind.primary,
      label: 'เปิดโต๊ะ',
      onPressed: () {
        final s = tablesCubit.state.posState;
        final free = s.tables
            .where((t) => !s.openTables.containsKey(t.id))
            .firstOrNull;
        context.go('/tables/${free?.id ?? s.tables.firstOrNull?.id ?? 't1'}');
      },
    ),
  ],
  if (viewId == 'bills' && billsCubit != null)
    ...buildBillsHeaderActions(billsCubit),
  if (viewId == 'stock' && stockCubit != null && stockCountBloc != null)
    ...buildStockHeaderActions(stockCubit, stockCountBloc),
  if (viewId == 'dashboard' && dashCubit != null)
    buildDashboardRangeSeg(dashCubit),
  if (viewId == 'reports' && repCubit != null)
    buildReportsMonthDropdown(repCubit),
];

/// Builds `/stock`, `/shift`, `/dashboard`, `/reports`, or `/setup` body.
Widget buildAnalyticsOrPlaceholderBody(
  BuildContext context, {
  required AppViewSpec viewSpec,
  required StaffMember me,
  required AppTokens tokens,
  required StockCubit? stockCubit,
  required ShiftBloc? shiftBloc,
  required BillsCubit? billsCubit,
  required DashboardCubit? existingDash,
  required ReportsCubit? existingRep,
  SetupCubit? existingSetup,
}) {
  if (viewSpec.id == 'stock' && stockCubit != null) return StockPage(staff: me);
  if (viewSpec.id == 'shift' && shiftBloc != null) {
    return ShiftPage(
      staffId: me.id,
      staffName: me.name,
      onGoTables: () => context.go('/tables'),
    );
  }
  if (viewSpec.id == 'dashboard' && existingDash != null) {
    return DashboardPage(
      onGoStockCount: () => context.go('/stock'),
      onGoSetupCosting: () => context.go('/setup'),
    );
  }
  if (viewSpec.id == 'reports' && existingRep != null) {
    return ReportsPage(
      onSelectDateForBills: (d) {
        billsCubit?.setDate(d);
        context.go('/bills?date=$d');
      },
      onGoSetupCosting: () => context.go('/setup'),
    );
  }
  if (viewSpec.id == 'setup' && existingSetup != null) {
    return SetupPage(staffRole: me.role, currentStaffId: me.id);
  }
  return buildSetupOrPlaceholderBody(viewSpec: viewSpec, tokens: tokens);
}

/// Builds the fallback placeholder body (including [SetupThemeSection] for
/// `/setup` when no [PosRepository] is provided).
Widget buildSetupOrPlaceholderBody({
  required AppViewSpec viewSpec,
  required AppTokens tokens,
}) => SingleChildScrollView(
  padding: const EdgeInsets.all(AppDimensions.space6),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (viewSpec.id == 'setup') ...[
        const SetupThemeSection(),
        const SizedBox(height: AppDimensions.space5),
      ],
      Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AppDimensions.r),
          border: Border.all(color: tokens.line),
        ),
        child: Empty(
          title: viewSpec.title,
          text: 'หน้าจอ ${viewSpec.label} (เตรียมเชื่อมข้อมูลในขั้นถัดไป)',
        ),
      ),
    ],
  ),
);
