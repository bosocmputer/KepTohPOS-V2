import 'dart:async';

import 'package:app/core/layout/app_shell.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/dev_components_page.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/roles.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/auth/presentation/pages/login_page.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:app/features/shift/presentation/pages/shift_page.dart';
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

/// Creates the application [GoRouter] with routes matching `VIEWS`:
/// `/login`, `/tables`, `/bills`, `/stock`, `/shift`, `/dashboard`,
/// `/reports`, `/setup`, plus debug-only `/dev/components`.
/// Enforces authentication and role-based route redirection.
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
      if (loc != '/login' && loc != '/dev/components') return '/login';
      return null;
    }
    if (loc == '/login') return '/tables';
    final viewId = loc.startsWith('/') ? loc.substring(1) : loc;
    if (viewId.isNotEmpty &&
        viewId != 'dev/components' &&
        !canAccessViewId(me.role, viewId)) {
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
/// Renders [ShiftPage] for `/shift`, theme settings for `/setup`, and
/// placeholder content for upcoming features.
class ShellPlaceholderPage extends StatefulWidget {
  const new({
    required this.viewSpec,
    super.key,
    this.staffRole = 'owner',
    this.initialDrawerOpen = false,
  });

  final AppViewSpec viewSpec;
  final String staffRole;
  final bool initialDrawerOpen;

  @override
  State<ShellPlaceholderPage> createState() => _ShellPlaceholderPageState();
}

class _ShellPlaceholderPageState extends State<ShellPlaceholderPage> {
  bool _manualOpenShiftModal = false;

  AuthCubit? _maybeAuthCubit(BuildContext context) {
    try {
      return context.watch<AuthCubit>();
    } on Object {
      return null;
    }
  }

  ShiftBloc? _maybeShiftBloc(BuildContext context) {
    try {
      return context.watch<ShiftBloc>();
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final authCubit = _maybeAuthCubit(context);
    final shiftBloc = _maybeShiftBloc(context);
    final me = authCubit?.state.currentStaff;
    final activeShift = shiftBloc?.state.activeShift;

    final effectiveStaffId = me?.id ?? 'st1';
    final effectiveStaffName = me?.name ?? 'พี่ต้อม (เจ้าของร้าน)';
    final effectiveRole = me?.role ?? widget.staffRole;
    final shiftTimeText = shiftBloc != null
        ? (activeShift != null ? thTime(activeShift.openedAt) : null)
        : '09:00';
    final shiftStaffName = shiftBloc != null && activeShift != null
        ? shiftBloc.state.staffNameOf(activeShift.staffId)
        : effectiveStaffName;

    final showOpenShiftModal =
        shiftBloc != null &&
        activeShift == null &&
        ((authCubit?.state.shouldPromptOpenShift ?? false) ||
            _manualOpenShiftModal);

    final Widget body;
    if (widget.viewSpec.id == 'shift' && shiftBloc != null) {
      body = ShiftPage(
        staffId: effectiveStaffId,
        staffName: effectiveStaffName,
        onGoTables: () => context.go('/tables'),
      );
    } else {
      final isSetup = widget.viewSpec.id == 'setup';
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: widget.viewSpec.title,
              desc: 'ร้านหมูกระทะ เก็บโต๊ะ',
            ),
            if (isSetup) ...[
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
          staffName: effectiveStaffName,
          staffRole: effectiveRole,
          shiftOpenTimeText: shiftTimeText,
          shiftStaffName: shiftStaffName,
          initialDrawerOpen: widget.initialDrawerOpen,
          onNavigate: (viewId) {
            if (viewId == 'dev/components') {
              unawaited(context.push('/dev/components'));
            } else {
              context.go('/$viewId');
            }
          },
          onShiftAction: () {
            if (activeShift != null) {
              context.go('/shift');
            } else {
              setState(() => _manualOpenShiftModal = true);
            }
          },
          onLogout: () {
            authCubit?.logout();
            context.go('/login');
          },
          child: body,
        ),
        if (showOpenShiftModal)
          OpenShiftModal(
            staffId: effectiveStaffId,
            staffName: effectiveStaffName,
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
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final themeState = context.watch<ThemeCubit>().state;
    final themeCubit = context.read<ThemeCubit>();

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space5),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppDimensions.r),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ธีมและการแสดงผล',
                style: textTheme.titleLarge?.copyWith(color: tokens.ink),
              ),
              const SizedBox(height: AppDimensions.space1),
              Text(
                'เลือกโหมดสว่าง มืด หรือตามเครื่อง',
                style: textTheme.bodySmall?.copyWith(color: tokens.muted),
              ),
            ],
          ),
          Wrap(
            spacing: AppDimensions.space2,
            children: AppThemeMode.values.map((mode) {
              final selected = themeState.mode == mode;
              return Btn(
                key: ValueKey('setup-mode-${mode.name}'),
                label: mode.label,
                size: BtnSize.sm,
                kind: selected ? BtnKind.primary : BtnKind.normal,
                onPressed: () => themeCubit.setMode(mode),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
