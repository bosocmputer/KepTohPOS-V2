import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/roles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  Widget _circleIcon(String icon, Color bg, Color fg, double size) => Container(
    width: AppDimensions.avatarSm,
    height: AppDimensions.avatarSm,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    child: Center(
      child: AppIcon(icon, size: size, color: fg),
    ),
  );

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
            _buildUserAndShiftCard(t, tt, isOpen),
            const SizedBox(height: AppDimensions.space4),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final v in views)
                      _buildNavItem(
                        v.id,
                        v.icon,
                        v.label,
                        v.id == baseId,
                        t,
                        tt,
                      ),
                    if (kDebugMode)
                      _buildNavItem(
                        'dev/components',
                        'grid',
                        'Components (dev)',
                        activeViewId == 'dev/components',
                        t,
                        tt,
                      ),
                  ],
                ),
              ),
            ),
            if (themeCubit != null) ...[
              const SizedBox(height: AppDimensions.space2),
              _buildThemeShortcut(themeCubit, t, tt),
            ],
            const SizedBox(height: AppDimensions.space3),
            _buildLogoutButton(t, tt),
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

  Widget _buildUserAndShiftCard(AppTokens t, TextTheme tt, bool isOpen) =>
      Container(
        padding: const EdgeInsets.all(AppDimensions.space3),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: t.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kRoles[staffRole] ?? staffRole,
              style: tt.labelSmall?.copyWith(color: t.muted),
            ),
            const SizedBox(height: AppDimensions.space2),
            Row(
              children: [
                Avatar(name: staffName),
                const SizedBox(width: AppDimensions.space2_5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffName,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isOpen
                            ? 'กะเปิด $shiftOpenTimeText น.'
                            : 'ยังไม่เปิดกะ',
                        style: tt.labelSmall?.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                Btn(
                  key: const ValueKey('sidebar-shift-btn'),
                  label: isOpen ? 'ปิดกะ' : 'เปิดกะ',
                  size: BtnSize.sm,
                  onPressed: onShiftAction ?? () => onSelectView('shift'),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildNavItem(
    String id,
    String icon,
    String label,
    bool selected,
    AppTokens t,
    TextTheme tt,
  ) {
    final fg = selected ? t.onPrimary : t.muted;
    final circleBg = selected ? t.primary.withValues(alpha: 0) : t.surface2;
    final keyName = id == 'dev/components' ? 'dev-components' : id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space1_5),
      child: Material(
        color: selected ? t.primary : t.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          key: ValueKey('drawer-nav-$keyName'),
          onTap: () => onSelectView(id),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space3,
              vertical: AppDimensions.space2,
            ),
            child: Row(
              children: [
                _circleIcon(icon, circleBg, fg, AppDimensions.iconLg),
                const SizedBox(width: AppDimensions.space3),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeShortcut(ThemeCubit cubit, AppTokens t, TextTheme tt) =>
      Container(
        padding: const EdgeInsets.all(AppDimensions.space2_5),
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ธีมและการแสดงผล',
              style: tt.labelSmall?.copyWith(color: t.muted),
            ),
            const SizedBox(height: AppDimensions.space1_5),
            Wrap(
              spacing: AppDimensions.space1_5,
              runSpacing: AppDimensions.space1_5,
              children: AppThemeMode.values.map((m) {
                final isSel = cubit.state.mode == m;
                return Btn(
                  key: ValueKey('mode-${m.name}'),
                  label: m.label,
                  size: BtnSize.sm,
                  kind: isSel ? BtnKind.primary : BtnKind.normal,
                  onPressed: () => cubit.setMode(m),
                );
              }).toList(),
            ),
          ],
        ),
      );

  Widget _buildLogoutButton(AppTokens t, TextTheme tt) => InkWell(
    key: const ValueKey('sidebar-logout-btn'),
    onTap: onLogout ?? () {},
    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.space2),
      child: Row(
        children: [
          _circleIcon('logout', t.primarySoft, t.primary, AppDimensions.iconMd),
          const SizedBox(width: AppDimensions.space3),
          Text('ออกจากระบบ', style: tt.bodyMedium?.copyWith(color: t.muted)),
        ],
      ),
    ),
  );
}
