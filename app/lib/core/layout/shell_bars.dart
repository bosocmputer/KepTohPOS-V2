import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/roles.dart';
import 'package:flutter/material.dart';

/// Top header bar for `AppShell` (`88px` on `>= 761`, compact on mobile).
class ShellHeaderBar extends StatelessWidget {
  const new({
    required this.height,
    required this.isMobile,
    required this.title,
    required this.subtitle,
    required this.staffName,
    required this.isShiftOpen,
    required this.actions,
    required this.onOpenDrawer,
    super.key,
  });

  final double height;
  final bool isMobile;
  final String title;
  final String subtitle;
  final String staffName;
  final bool isShiftOpen;
  final List<Widget> actions;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const ValueKey('shell-header'),
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppDimensions.space3 : AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          Btn(
            key: const ValueKey('shell-menu-btn'),
            kind: BtnKind.ghost,
            icon: 'sidebar',
            semanticLabel: 'เปิดเมนู',
            onPressed: onOpenDrawer,
          ),
          const SizedBox(width: AppDimensions.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.displaySmall?.copyWith(
                    color: tokens.ink,
                    fontSize: isMobile
                        ? AppDimensions.fsLg
                        : AppDimensions.fs2xl,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: tokens.muted,
                    fontSize: isMobile
                        ? AppDimensions.fsXs
                        : AppDimensions.fsSm,
                  ),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            ...actions,
            const SizedBox(width: AppDimensions.space2_5),
          ],
          Semantics(
            button: true,
            label:
                'บัญชีและกะ · $staffName · '
                '${isShiftOpen ? "กะเปิด" : "ยังไม่เปิดกะ"}',
            child: InkWell(
              key: const ValueKey('shell-user-btn'),
              onTap: onOpenDrawer,
              customBorder: const CircleBorder(),
              child: Stack(
                children: [
                  Avatar(name: staffName),
                  Positioned(
                    right: AppDimensions.space0,
                    bottom: AppDimensions.space0,
                    child: Container(
                      width: AppDimensions.statusDotMd,
                      height: AppDimensions.statusDotMd,
                      decoration: BoxDecoration(
                        color: isShiftOpen ? tokens.success : tokens.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tokens.surface,
                          width: AppDimensions.borderBold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile bottom navigation bar (`<= 760px`: 4 items + "เพิ่มเติม").
class MobileBottomNavBar extends StatelessWidget {
  const new({
    required this.allowedViews,
    required this.activeViewId,
    required this.onSelectView,
    required this.onOpenMore,
    super.key,
  });

  final List<AppViewSpec> allowedViews;
  final String activeViewId;
  final ValueChanged<String> onSelectView;
  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final keep = allowedViews.length > 5 ? 4 : allowedViews.length;
    final visibleViews = allowedViews.take(keep).toList();
    final hasMore = allowedViews.length > keep;
    final moreActive =
        hasMore && allowedViews.skip(keep).any((v) => v.id == activeViewId);

    return Container(
      key: const ValueKey('shell-bottom-nav'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space1_5,
        vertical: AppDimensions.space1_5,
      ),
      decoration: BoxDecoration(
        color: tokens.side,
        border: Border(top: BorderSide(color: tokens.sideLine)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final v in visibleViews)
              Expanded(
                child: _BottomNavButton(
                  key: ValueKey('bottom-nav-${v.id}'),
                  icon: v.icon,
                  label: v.label,
                  selected: v.id == activeViewId,
                  onTap: () => onSelectView(v.id),
                ),
              ),
            if (hasMore)
              Expanded(
                child: _BottomNavButton(
                  key: const ValueKey('bottom-nav-more'),
                  icon: 'menu',
                  label: 'เพิ่มเติม',
                  selected: moreActive,
                  onTap: onOpenMore,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fg = selected ? tokens.onPrimary : tokens.sideInk;
    return Material(
      color: selected ? tokens.primary : tokens.side.withValues(alpha: 0),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.space2,
            horizontal: AppDimensions.spaceHalf,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: AppDimensions.iconLg, color: fg),
              const SizedBox(height: AppDimensions.space1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontSize: AppDimensions.fsXs,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
