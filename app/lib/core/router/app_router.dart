import 'dart:async';

import 'package:app/core/router/shell_placeholder_page.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/dev_components_page.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/auth/presentation/pages/login_page.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:app/features/reports/presentation/pages/reports_page.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:app/features/shift/presentation/pages/shift_page.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:app/features/stock/presentation/pages/stock_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

export 'package:app/core/router/shell_placeholder_page.dart';
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

/// Builds `/stock`, `/shift`, `/dashboard`, `/reports`, or `/setup` body.
Widget buildAnalyticsOrPlaceholderBody(
  BuildContext context, {
  required AppViewSpec viewSpec,
  required StaffMember me,
  required AppTokens tokens,
  required PosRepository? repo,
  required StockCubit? stockCubit,
  required ShiftBloc? shiftBloc,
  required BillsCubit? billsCubit,
  required DashboardCubit? existingDash,
  required ReportsCubit? existingRep,
  required DateTime? now,
}) {
  if (viewSpec.id == 'stock' && stockCubit != null) return StockPage(staff: me);
  if (viewSpec.id == 'shift' && shiftBloc != null) {
    return ShiftPage(
      staffId: me.id,
      staffName: me.name,
      onGoTables: () => context.go('/tables'),
    );
  }
  if (viewSpec.id == 'dashboard' && (existingDash != null || repo != null)) {
    final page = DashboardPage(
      onGoStockCount: () => context.go('/stock'),
      onGoSetupCosting: () => context.go('/setup'),
    );
    return existingDash != null
        ? page
        : BlocProvider(
            key: const ValueKey('dashboard-scope'),
            create: (_) => DashboardCubit(repo!, now: now),
            child: page,
          );
  }
  if (viewSpec.id == 'reports' && (existingRep != null || repo != null)) {
    final page = ReportsPage(
      onSelectDateForBills: (d) {
        billsCubit?.setDate(d);
        context.go('/bills?date=$d');
      },
      onGoSetupCosting: () => context.go('/setup'),
    );
    return existingRep != null
        ? page
        : BlocProvider(
            key: const ValueKey('reports-scope'),
            create: (_) => ReportsCubit(repo!, now: now),
            child: page,
          );
  }
  return buildSetupOrPlaceholderBody(viewSpec: viewSpec, tokens: tokens);
}

/// Builds the fallback placeholder body (including [SetupThemeSection] for
/// `/setup`).
Widget buildSetupOrPlaceholderBody({
  required AppViewSpec viewSpec,
  required AppTokens tokens,
}) => SingleChildScrollView(
  padding: const EdgeInsets.all(AppDimensions.space6),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeader(title: viewSpec.title, desc: 'ร้านหมูกระทะ เก็บโต๊ะ'),
      if (viewSpec.id == 'setup') ...[
        const SizedBox(height: AppDimensions.space5),
        const SetupThemeSection(),
      ],
      const SizedBox(height: AppDimensions.space5),
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

/// Theme switcher card shown inside the Setup placeholder screen.
class SetupThemeSection extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final mode = context.watch<ThemeCubit>().state.mode;
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
                    onPressed: () => context.read<ThemeCubit>().setMode(m),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
