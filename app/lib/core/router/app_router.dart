import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Creates the application [GoRouter].
GoRouter createAppRouter() => GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (context, state) => const F0BootstrapPage()),
  ],
);

/// F0 empty shell page allowing live switching of brand (`figma` / `team`)
/// and theme mode (`light` / `dark` / `system`).
class F0BootstrapPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final themeState = context.watch<ThemeCubit>().state;
    final cubit = context.read<ThemeCubit>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.space6),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.space6),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.r),
                  border: Border.all(color: tokens.line),
                  boxShadow: tokens.shadows,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KepToh POS',
                      style: textTheme.displaySmall?.copyWith(
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space1),
                    Text(
                      'ธีมและการแสดงผล',
                      style: textTheme.bodySmall?.copyWith(color: tokens.muted),
                    ),
                    const SizedBox(height: AppDimensions.space5),
                    Text(
                      'ธีมสี',
                      style: textTheme.bodyMedium?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space2),
                    Wrap(
                      spacing: AppDimensions.space2,
                      children: AppBrand.values.map((brand) {
                        final selected = themeState.brand == brand;
                        return _SegmentChip(
                          key: ValueKey('brand-${brand.name}'),
                          label: brand.label,
                          selected: selected,
                          onTap: () => cubit.setBrand(brand),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppDimensions.space4),
                    Text(
                      'โหมด',
                      style: textTheme.bodyMedium?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space2),
                    Wrap(
                      spacing: AppDimensions.space2,
                      children: AppThemeMode.values.map((mode) {
                        final selected = themeState.mode == mode;
                        return _SegmentChip(
                          key: ValueKey('mode-${mode.name}'),
                          label: mode.label,
                          selected: selected,
                          onTap: () => cubit.setMode(mode),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: selected ? tokens.primary : tokens.surface2,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppDimensions.tap,
            minWidth: 88,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space4,
              vertical: AppDimensions.space2,
            ),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? tokens.onPrimary : tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
