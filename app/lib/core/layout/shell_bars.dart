import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/roles.dart';
import 'package:flutter/material.dart';

/// Unified top header bar for `AppShell` (`64px` at height `<= 820`, `72px` at
/// `1366x1024`, `52px` on mobile).
class ShellHeaderBar extends StatefulWidget {
  const new({
    required this.height,
    required this.isMobile,
    required this.staffName,
    required this.isShiftOpen,
    required this.actions,
    required this.onOpenDrawer,
    super.key,
    this.horizontalPadding,
    this.pageTitle = 'โต๊ะและขาย',
    this.titleWidget,
    this.searchQuery = '',
    this.searchPlaceholder = 'ค้นหา',
    this.onSearchChanged,
  });

  final double height;
  final double? horizontalPadding;
  final bool isMobile;
  final bool isShiftOpen;
  final String staffName;
  final String pageTitle;
  final String searchQuery;
  final String searchPlaceholder;
  final List<Widget> actions;
  final VoidCallback onOpenDrawer;
  final Widget? titleWidget;
  final ValueChanged<String>? onSearchChanged;

  @override
  State<ShellHeaderBar> createState() => _ShellHeaderBarState();
}

class _ShellHeaderBarState extends State<ShellHeaderBar> {
  bool _mobileSearchOpen = false;

  @override
  void didUpdateWidget(covariant ShellHeaderBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onSearchChanged == null) _mobileSearchOpen = false;
  }

  Widget _buildSearchBox() => SearchBox(
    value: widget.searchQuery,
    placeholder: widget.searchPlaceholder,
    onChanged: widget.onSearchChanged!,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final screenW = MediaQuery.sizeOf(context).width;
    final hPad =
        widget.horizontalPadding ??
        (widget.isMobile ? 12 : AppDimensions.pagePadding(screenW));
    final hasSearch = widget.onSearchChanged != null;
    final titleNode =
        widget.titleWidget ??
        Text(
          widget.pageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (widget.isMobile ? tt.titleMedium : tt.headlineMedium)
              ?.copyWith(color: t.ink, fontWeight: FontWeight.w700),
        );
    final menuBtn = Btn(
      key: const ValueKey('shell-menu-btn'),
      icon: 'sidebar',
      semanticLabel: 'เปิดเมนู',
      onPressed: widget.onOpenDrawer,
    );

    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth.isFinite ? c.maxWidth : screenW;
        final twoRows =
            !widget.isMobile &&
            maxW < 980 &&
            (hasSearch || widget.actions.length > 1);
        final userChip = StaffShiftChip(
          key: const ValueKey('shell-user-btn'),
          staffName: widget.staffName,
          isShiftOpen: widget.isShiftOpen,
          compact: widget.isMobile || maxW < 640,
          onTap: widget.onOpenDrawer,
        );
        return Container(
          key: const ValueKey('shell-header'),
          height: twoRows ? null : widget.height + topInset,
          padding: EdgeInsets.fromLTRB(
            hPad,
            topInset + (twoRows ? 10 : 0),
            hPad,
            twoRows ? 10 : 0,
          ),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(bottom: BorderSide(color: t.line)),
          ),
          child: twoRows
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        menuBtn,
                        const SizedBox(width: 12),
                        Expanded(child: titleNode),
                        const SizedBox(width: 12),
                        userChip,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (hasSearch)
                          Expanded(child: _buildSearchBox())
                        else
                          const Spacer(),
                        for (final a in widget.actions) ...[
                          const SizedBox(width: 8),
                          a,
                        ],
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    menuBtn,
                    if (widget.isMobile) ...[
                      const SizedBox(width: 8),
                      if (_mobileSearchOpen && hasSearch)
                        Expanded(child: _buildSearchBox())
                      else
                        Expanded(child: titleNode),
                      if (hasSearch) ...[
                        const SizedBox(width: 4),
                        Btn(
                          key: const ValueKey('shell-mobile-search-btn'),
                          kind: BtnKind.ghost,
                          icon: _mobileSearchOpen ? 'x' : 'search',
                          semanticLabel: _mobileSearchOpen
                              ? 'ปิดค้นหา'
                              : 'ค้นหา',
                          onPressed: () {
                            if (_mobileSearchOpen) {
                              widget.onSearchChanged?.call('');
                            }
                            setState(
                              () => _mobileSearchOpen = !_mobileSearchOpen,
                            );
                          },
                        ),
                        if (!_mobileSearchOpen) const SizedBox(width: 4),
                      ],
                    ] else ...[
                      const SizedBox(width: 12),
                      Expanded(child: titleNode),
                      const SizedBox(width: 12),
                      if (hasSearch) ...[
                        SizedBox(width: 240, child: _buildSearchBox()),
                        const SizedBox(width: 10),
                      ],
                      for (final a in widget.actions) ...[
                        a,
                        const SizedBox(width: 10),
                      ],
                    ],
                    userChip,
                  ],
                ),
        );
      },
    );
  }
}

/// Provides the desktop `ShellHeaderBar` builder to split-screen views.
class ShellDesktopHeaderScope extends InheritedWidget {
  const new({required this.headerBuilder, required super.child, super.key});
  final Widget Function({Widget? titleWidget, List<Widget> extraActions})
  headerBuilder;
  static ShellDesktopHeaderScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellDesktopHeaderScope>();
  @override
  bool updateShouldNotify(ShellDesktopHeaderScope oldWidget) => true;
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

  Widget _item(
    BuildContext context,
    String key,
    String icon,
    String label,
    bool sel,
    VoidCallback onTap,
  ) {
    final t = context.tokens;
    final rad = BorderRadius.circular(AppDimensions.radiusMd);
    final fg = sel ? t.onPrimary : t.sideInk;
    return Expanded(
      child: Material(
        key: ValueKey(key),
        color: sel ? t.primary : t.side.withValues(alpha: 0),
        borderRadius: rad,
        child: InkWell(
          onTap: onTap,
          borderRadius: rad,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(icon, size: AppDimensions.iconLg, color: fg),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: sel ? t.onPrimary : t.sideInkStrong,
                    fontSize: AppDimensions.fsXs,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final keep = allowedViews.length > 5 ? 4 : allowedViews.length;
    final moreSel =
        allowedViews.length > keep &&
        allowedViews.skip(keep).any((v) => v.id == activeViewId);
    return Container(
      key: const ValueKey('shell-bottom-nav'),
      padding: const EdgeInsets.all(AppDimensions.space1),
      decoration: BoxDecoration(
        color: t.side,
        border: Border(top: BorderSide(color: t.sideLine)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final v in allowedViews.take(keep))
              _item(
                context,
                'bottom-nav-${v.id}',
                v.icon,
                v.label,
                v.id == activeViewId,
                () => onSelectView(v.id),
              ),
            if (allowedViews.length > keep)
              _item(
                context,
                'bottom-nav-more',
                'menu',
                'เพิ่มเติม',
                moreSel,
                onOpenMore,
              ),
          ],
        ),
      ),
    );
  }
}
