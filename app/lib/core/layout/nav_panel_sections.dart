import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/roles.dart';
import 'package:flutter/material.dart';

/// User and active shift card displayed at the top of `NavPanel`
/// (`design/figma/cashier_sidebar.png`).
class NavUserAndShiftCard extends StatelessWidget {
  const new({
    required this.staffName,
    required this.staffRole,
    required this.isOpen,
    required this.onShiftPressed,
    super.key,
    this.shiftOpenTimeText,
  });

  final String staffName;
  final String staffRole;
  final bool isOpen;
  final String? shiftOpenTimeText;
  final VoidCallback onShiftPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space3),
      decoration: BoxDecoration(
        color: t.surface2,
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
                      isOpen ? 'กะเปิด $shiftOpenTimeText น.' : 'ยังไม่เปิดกะ',
                      style: tt.labelSmall?.copyWith(
                        color: isOpen ? t.successInk : t.muted,
                        fontWeight: isOpen ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Btn(
                key: const ValueKey('sidebar-shift-btn'),
                label: isOpen ? 'ปิดกะ' : 'เปิดกะ',
                kind: isOpen ? BtnKind.normal : BtnKind.primary,
                size: BtnSize.sm,
                onPressed: onShiftPressed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Single navigation item row inside `NavPanel`.
class NavItemTile extends StatelessWidget {
  const new({
    required this.id,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String id;
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final fg = selected ? t.onPrimary : t.sideInk;
    final circleBg = selected ? t.primary.withValues(alpha: 0) : t.surface2;
    final keyName = id == 'dev/components' ? 'dev-components' : id;
    final compactH = MediaQuery.sizeOf(context).height < 840;

    return Padding(
      padding: EdgeInsets.only(
        bottom: compactH ? AppDimensions.space1 : AppDimensions.space1_5,
      ),
      child: Material(
        color: selected ? t.primary : t.side.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          key: ValueKey('drawer-nav-$keyName'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.space3,
              vertical: compactH
                  ? AppDimensions.space1_5
                  : AppDimensions.space2,
            ),
            child: Row(
              children: [
                NavCircleIcon(
                  icon: icon,
                  bg: circleBg,
                  fg: fg,
                  size: AppDimensions.iconLg,
                ),
                const SizedBox(width: AppDimensions.space3),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(
                      color: selected ? t.onPrimary : t.sideInkStrong,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
}

/// Theme mode selector shortcut card inside `NavPanel`.
class NavThemeShortcut extends StatelessWidget {
  const new({required this.cubit, super.key});

  final ThemeCubit cubit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space2_5),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: t.line),
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
  }
}

/// Borderless logout button at the bottom of `NavPanel`.
class NavLogoutButton extends StatelessWidget {
  const new({this.onLogout, super.key});

  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      key: const ValueKey('sidebar-logout-btn'),
      onTap: onLogout ?? () {},
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space2),
        child: Row(
          children: [
            NavCircleIcon(
              icon: 'logout',
              bg: t.primarySoft,
              fg: t.primary,
              size: AppDimensions.iconMd,
            ),
            const SizedBox(width: AppDimensions.space3),
            Text('ออกจากระบบ', style: tt.bodyMedium?.copyWith(color: t.muted)),
          ],
        ),
      ),
    );
  }
}

/// Circular icon badge used in `NavPanel` items and logout action.
class NavCircleIcon extends StatelessWidget {
  const new({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.size,
    super.key,
  });

  final String icon;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: AppDimensions.avatarSm,
    height: AppDimensions.avatarSm,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    child: Center(
      child: AppIcon(icon, size: size, color: fg),
    ),
  );
}
