import 'package:app/core/layout/nav_drawer.dart';
import 'package:app/core/layout/shell_bars.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/roles.dart';
import 'package:flutter/material.dart';

export 'package:app/core/layout/nav_drawer.dart';
export 'package:app/core/layout/shell_bars.dart';

/// Responsive application shell (`AppShell` in Section 1 & 4 of
/// `docs/llms/flutter-plan.md`):
/// - `>= 761`: Header `88px` + slide-over Sidebar `365px` with dark backdrop.
/// - `<= 760`: Compact Header + Bottom navigation bar (4 items + "เพิ่มเติม").
class AppShell extends StatefulWidget {
  const new({
    required this.activeViewId,
    required this.onNavigate,
    required this.child,
    super.key,
    this.pageTitle = 'โต๊ะและขาย',
    this.shopName = 'ร้านหมูกระทะ เก็บโต๊ะ',
    this.dateKey = '2026-11-04',
    this.staffName = 'พี่ต้อม (เจ้าของร้าน)',
    this.staffRole = 'owner',
    this.shiftOpenTimeText = '09:00',
    this.shiftStaffName = 'พี่ต้อม (เจ้าของร้าน)',
    this.initialDrawerOpen = false,
    this.delegateDesktopHeader = false,
    this.headerActions = const <Widget>[],
    this.searchQuery = '',
    this.searchPlaceholder = 'ค้นหา',
    this.onSearchChanged,
    this.onShiftAction,
    this.onLogout,
  });

  final String activeViewId;
  final ValueChanged<String> onNavigate;
  final Widget child;
  final String pageTitle;
  final String shopName;
  final String dateKey;
  final String staffName;
  final String staffRole;
  final String? shiftOpenTimeText;
  final String? shiftStaffName;
  final bool initialDrawerOpen;
  final bool delegateDesktopHeader;
  final List<Widget> headerActions;
  final String searchQuery;
  final String searchPlaceholder;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onShiftAction;
  final VoidCallback? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late bool _drawerOpen;

  @override
  void initState() {
    super.initState();
    _drawerOpen = widget.initialDrawerOpen;
  }

  void _handleSelectView(String viewId) {
    setState(() => _drawerOpen = false);
    widget.onNavigate(viewId);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final allowedViews = allowedViewsForRole(widget.staffRole);
    final hasAccess =
        widget.activeViewId == 'dev/components' ||
        canAccessViewId(widget.staffRole, widget.activeViewId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final isMobile = screenW <= AppDimensions.mobileBp;
        final headerHeight = AppDimensions.topbarHeight(screenW);
        final pagePad = isMobile
            ? AppDimensions.space3
            : AppDimensions.pagePadding(screenW);
        final delegateHeader =
            !isMobile && widget.delegateDesktopHeader && hasAccess;

        ShellHeaderBar buildHeader({List<Widget> extraActions = const []}) =>
            ShellHeaderBar(
              height: headerHeight,
              isMobile: isMobile,
              horizontalPadding: pagePad,
              pageTitle: widget.pageTitle,
              staffName: widget.staffName,
              isShiftOpen: widget.shiftOpenTimeText != null,
              actions: <Widget>[...extraActions, ...widget.headerActions],
              searchQuery: widget.searchQuery,
              searchPlaceholder: widget.searchPlaceholder,
              onSearchChanged: widget.onSearchChanged,
              onOpenDrawer: () => setState(() => _drawerOpen = true),
            );

        return Scaffold(
          backgroundColor: tokens.bg,
          body: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!delegateHeader) buildHeader(),
                  Expanded(
                    child: hasAccess
                        ? (delegateHeader
                              ? ShellDesktopHeaderScope(
                                  headerBuilder: buildHeader,
                                  child: widget.child,
                                )
                              : SafeArea(
                                  top: false,
                                  bottom: !isMobile,
                                  child: widget.child,
                                ))
                        : SafeArea(
                            top: false,
                            bottom: !isMobile,
                            child: Padding(
                              padding: EdgeInsets.all(pagePad),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: tokens.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.r,
                                  ),
                                  border: Border.all(color: tokens.line),
                                ),
                                child: Empty(
                                  title: 'ไม่มีสิทธิ์เข้าหน้านี้',
                                  text:
                                      '${kRoles[widget.staffRole] ?? ""}'
                                      ' เข้าหน้านี้ไม่ได้',
                                  action: Btn(
                                    label: 'กลับหน้าโต๊ะ',
                                    kind: BtnKind.primary,
                                    onPressed: () =>
                                        _handleSelectView('tables'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (isMobile)
                    MobileBottomNavBar(
                      allowedViews: allowedViews,
                      activeViewId: widget.activeViewId.split('/').first,
                      onSelectView: _handleSelectView,
                      onOpenMore: () => setState(() => _drawerOpen = true),
                    ),
                ],
              ),
              if (_drawerOpen)
                NavDrawer(
                  onClose: () => setState(() => _drawerOpen = false),
                  panel: NavPanel(
                    activeViewId: widget.activeViewId,
                    staffName: widget.staffName,
                    staffRole: widget.staffRole,
                    shiftOpenTimeText: widget.shiftOpenTimeText,
                    shiftStaffName: widget.shiftStaffName,
                    onSelectView: _handleSelectView,
                    onClose: () => setState(() => _drawerOpen = false),
                    onShiftAction: widget.onShiftAction,
                    onLogout: widget.onLogout,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Overlay slide-over drawer (`365px` width + dark scrim backdrop per Figma).
class NavDrawer extends StatelessWidget {
  const new({required this.panel, required this.onClose, super.key});

  final NavPanel panel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('drawer-scrim'),
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: ColoredBox(color: tokens.scrim),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppDimensions.drawerW),
            child: DecoratedBox(
              decoration: BoxDecoration(boxShadow: tokens.shadows),
              child: panel,
            ),
          ),
        ),
      ],
    );
  }
}
