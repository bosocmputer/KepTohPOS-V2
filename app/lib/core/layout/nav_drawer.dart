import 'package:app/core/layout/nav_panel_sections.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/roles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/core/layout/nav_panel_sections.dart';

/// Slide-over navigation panel content (`NavPanel` in `prototype/index.html`
/// & Figma `design/figma/cashier_sidebar.png`).
class NavPanel extends StatelessWidget {
  const new({
    required this.activeViewId,
    required this.staffName,
    required this.staffRole,
    required this.onSelectView,
    super.key,
    this.shiftOpenTimeText,
    this.shiftStaffName,
    this.onClose,
    this.onShiftAction,
    this.onLogout,
  });

  final String activeViewId;
  final String staffName;
  final String staffRole;
  final ValueChanged<String> onSelectView;
  final String? shiftOpenTimeText;
  final String? shiftStaffName;
  final VoidCallback? onClose;
  final VoidCallback? onShiftAction;
  final VoidCallback? onLogout;

  ThemeCubit? _maybeThemeCubit(BuildContext context) {
    try {
      return context.watch<ThemeCubit>();
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final baseId = activeViewId.split('/').first;
    final views = allowedViewsForRole(staffRole);
    final isOpen = shiftOpenTimeText != null;
    final themeCubit = _maybeThemeCubit(context);

    return Container(
      width: AppDimensions.drawerW,
      height: double.infinity,
      color: t.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space4,
        vertical: AppDimensions.space5,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBrandRow(t, tt),
            const SizedBox(height: AppDimensions.space4),
            NavUserAndShiftCard(
              staffName: staffName,
              staffRole: staffRole,
              isOpen: isOpen,
              shiftOpenTimeText: shiftOpenTimeText,
              onShiftPressed: onShiftAction ?? () => onSelectView('shift'),
            ),
            const SizedBox(height: AppDimensions.space4),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final v in views)
                      NavItemTile(
                        id: v.id,
                        icon: v.icon,
                        label: v.label,
                        selected: v.id == baseId,
                        onTap: () => onSelectView(v.id),
                      ),
                    if (kDebugMode)
                      NavItemTile(
                        id: 'dev/components',
                        icon: 'grid',
                        label: 'Components (dev)',
                        selected: activeViewId == 'dev/components',
                        onTap: () => onSelectView('dev/components'),
                      ),
                  ],
                ),
              ),
            ),
            if (themeCubit != null) ...[
              const SizedBox(height: AppDimensions.space2),
              NavThemeShortcut(cubit: themeCubit),
            ],
            const SizedBox(height: AppDimensions.space3),
            NavLogoutButton(onLogout: onLogout),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandRow(AppTokens t, TextTheme tt) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Container(
            width: AppDimensions.avatarSm,
            height: AppDimensions.avatarSm,
            decoration: BoxDecoration(
              color: t.primary,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Center(child: AppIcon('flame', color: t.onPrimary)),
          ),
          const SizedBox(width: AppDimensions.space3),
          Text('KepToh POS', style: tt.displaySmall?.copyWith(color: t.ink)),
        ],
      ),
      if (onClose != null)
        Btn(
          kind: BtnKind.ghost,
          icon: 'sidebar',
          semanticLabel: 'ปิดเมนู',
          onPressed: onClose,
        ),
    ],
  );
}
