import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/roles.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final baseViewId = activeViewId.split('/').first;
    final allowedViews = allowedViewsForRole(staffRole);
    final isShiftOpen = shiftOpenTimeText != null;

    return Container(
      width: AppDimensions.drawerW,
      height: double.infinity,
      color: tokens.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space4,
        vertical: AppDimensions.space5,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBrandRow(tokens, textTheme),
            const SizedBox(height: AppDimensions.space4),
            _buildUserCard(tokens, textTheme),
            const SizedBox(height: AppDimensions.space3),
            _buildShiftCard(tokens, textTheme, isShiftOpen),
            const SizedBox(height: AppDimensions.space4),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: allowedViews
                      .map(
                        (v) => _buildNavItem(v, baseViewId, tokens, textTheme),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space3),
            Text(
              'ข้อมูลตัวอย่างสำหรับทดลอง',
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: tokens.muted,
                fontSize: AppDimensions.fsXs,
              ),
            ),
            const SizedBox(height: AppDimensions.space2),
            Btn(
              label: 'ออกจากระบบ',
              icon: 'logout',
              block: true,
              onPressed: onLogout ?? () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandRow(AppTokens tokens, TextTheme textTheme) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Container(
            width: AppDimensions.avatarSm,
            height: AppDimensions.avatarSm,
            decoration: BoxDecoration(
              color: tokens.primary,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Center(child: AppIcon('flame', color: tokens.onPrimary)),
          ),
          const SizedBox(width: AppDimensions.space3),
          Text(
            'KepToh',
            style: textTheme.displaySmall?.copyWith(
              color: tokens.ink,
              fontSize: AppDimensions.fsXl,
            ),
          ),
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

  Widget _buildUserCard(AppTokens tokens, TextTheme textTheme) => Container(
    padding: const EdgeInsets.all(AppDimensions.space3),
    decoration: BoxDecoration(
      color: tokens.surface2,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      border: Border.all(color: tokens.line),
    ),
    child: Row(
      children: [
        Avatar(name: staffName),
        const SizedBox(width: AppDimensions.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                staffName,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                kRoles[staffRole] ?? staffRole,
                style: textTheme.labelSmall?.copyWith(
                  color: tokens.muted,
                  fontSize: AppDimensions.fsXs,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildShiftCard(
    AppTokens tokens,
    TextTheme textTheme,
    bool isShiftOpen,
  ) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.space3,
      vertical: AppDimensions.space2_5,
    ),
    decoration: BoxDecoration(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      border: Border.all(color: tokens.line),
    ),
    child: Row(
      children: [
        Container(
          width: AppDimensions.statusDotSm,
          height: AppDimensions.statusDotSm,
          decoration: BoxDecoration(
            color: isShiftOpen ? tokens.success : tokens.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppDimensions.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isShiftOpen ? 'กะเปิด $shiftOpenTimeText น.' : 'ยังไม่เปิดกะ',
                style: textTheme.bodySmall?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isShiftOpen && shiftStaffName != null)
                Text(
                  shiftStaffName!,
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.muted,
                    fontSize: AppDimensions.fsXs,
                  ),
                ),
            ],
          ),
        ),
        Btn(
          label: isShiftOpen ? 'ปิดกะ' : 'เปิดกะ',
          size: BtnSize.sm,
          onPressed: onShiftAction ?? () => onSelectView('shift'),
        ),
      ],
    ),
  );

  Widget _buildNavItem(
    AppViewSpec view,
    String baseViewId,
    AppTokens tokens,
    TextTheme textTheme,
  ) {
    final selected = view.id == baseViewId;
    final fg = selected ? tokens.onPrimary : tokens.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space1),
      child: Material(
        color: selected ? tokens.primary : tokens.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          key: ValueKey('drawer-nav-${view.id}'),
          onTap: () => onSelectView(view.id),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppDimensions.tap),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space4,
                vertical: AppDimensions.space3,
              ),
              child: Row(
                children: [
                  AppIcon(view.icon, size: AppDimensions.iconLg, color: fg),
                  const SizedBox(width: AppDimensions.space3),
                  Text(
                    view.label,
                    style: textTheme.bodyLarge?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
