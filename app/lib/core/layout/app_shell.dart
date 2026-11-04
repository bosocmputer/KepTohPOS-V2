import 'package:app/core/layout/nav_drawer.dart';
import 'package:app/core/layout/shell_bars.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
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
    this.shopName = 'ร้านหมูกระทะ เก็บโต๊ะ',
    this.dateKey = '2026-11-04',
    this.staffName = 'พี่ต้อม (เจ้าของร้าน)',
    this.staffRole = 'owner',
    this.shiftOpenTimeText = '15:30',
    this.shiftStaffName = 'พี่ต้อม (เจ้าของร้าน)',
    this.initialDrawerOpen = false,
    this.headerActions = const <Widget>[],
    this.onLogout,
  });

  final String activeViewId;
  final ValueChanged<String> onNavigate;
  final Widget child;
  final String shopName;
  final String dateKey;
  final String staffName;
  final String staffRole;
  final String? shiftOpenTimeText;
  final String? shiftStaffName;
  final bool initialDrawerOpen;
  final List<Widget> headerActions;
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

  AppViewSpec get _currentView {
    final base = widget.activeViewId.split('/').first;
    for (final v in kAppViews) {
      if (v.id == base) return v;
    }
    return kAppViews.first;
  }

  void _handleSelectView(String viewId) {
    setState(() => _drawerOpen = false);
    widget.onNavigate(viewId);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final allowedViews = allowedViewsForRole(widget.staffRole);
    final hasAccess = canAccessViewId(widget.staffRole, widget.activeViewId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= AppDimensions.mobileBp;
        final headerHeight = isMobile
            ? AppDimensions.btnLgH
            : AppDimensions.headerH;

        return Scaffold(
          backgroundColor: tokens.bg,
          body: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShellHeaderBar(
                    height: headerHeight,
                    isMobile: isMobile,
                    title: _currentView.title,
                    subtitle: '${widget.shopName} · ${thDate(widget.dateKey)}',
                    staffName: widget.staffName,
                    isShiftOpen: widget.shiftOpenTimeText != null,
                    actions: widget.headerActions,
                    onOpenDrawer: () => setState(() => _drawerOpen = true),
                  ),
                  Expanded(
                    child: hasAccess
                        ? widget.child
                        : Padding(
                            padding: const EdgeInsets.all(AppDimensions.space6),
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
                                  onPressed: () => _handleSelectView('tables'),
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
