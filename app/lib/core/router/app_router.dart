import 'package:app/core/layout/app_shell.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/dev_components_page.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/roles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Creates the application [GoRouter] with routes matching `VIEWS`:
/// `/tables`, `/bills`, `/stock`, `/shift`, `/dashboard`, `/reports`, `/setup`
/// plus debug-only `/dev/components`.
GoRouter createAppRouter({String initialLocation = '/tables'}) => GoRouter(
  initialLocation: initialLocation,
  routes: <RouteBase>[
    GoRoute(path: '/', redirect: (_, _) => '/tables'),
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

/// F2 placeholder screen for each `VIEWS` route wrapped in [AppShell].
/// `/tables` (and other non-setup placeholder pages) shows only [PageHeader] +
/// [Empty] state; `/setup` includes the theme mode selector section.
class ShellPlaceholderPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isSetup = viewSpec.id == 'setup';

    return AppShell(
      activeViewId: viewSpec.id,
      staffRole: staffRole,
      initialDrawerOpen: initialDrawerOpen,
      onNavigate: (viewId) => context.go('/$viewId'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(title: viewSpec.title, desc: 'ร้านหมูกระทะ เก็บโต๊ะ'),
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
                title: viewSpec.title,
                text:
                    'หน้าจอ ${viewSpec.label} (เตรียมเชื่อมข้อมูลในขั้นถัดไป)',
              ),
            ),
          ],
        ),
      ),
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
