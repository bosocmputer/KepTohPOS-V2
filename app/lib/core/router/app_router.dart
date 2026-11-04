import 'dart:async';

import 'package:app/core/router/shell_placeholder_page.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/dev_components_page.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

export 'package:app/core/router/shell_placeholder_page.dart';

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
        builder: (context, state) =>
            ShellPlaceholderPage(viewSpec: view, now: now),
      ),
    if (kDebugMode)
      GoRoute(
        path: '/dev/components',
        builder: (context, state) => const DevComponentsPage(),
      ),
  ],
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
