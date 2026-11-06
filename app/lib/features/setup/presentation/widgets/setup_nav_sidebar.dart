import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Surface card container for `/setup` panels.
class SetupCard extends StatelessWidget {
  const new({required this.child, super.key, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.space4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.r),
        border: Border.all(color: t.line),
        boxShadow: t.shadows,
      ),
      child: child,
    );
  }
}

/// Metadata for a single `/setup` navigation item.
class SetupTabSpec {
  const new(this.id, this.label, this.icon, this.group);
  final String id;
  final String label;
  final String icon;
  final String group;
}

/// Ordered list of all 13 `/setup` sections grouped into 4 categories.
const List<SetupTabSpec> kSetupTabs = [
  SetupTabSpec('shop', 'ร้านและใบเสร็จ', 'setup', 'ร้านและต้นทุน'),
  SetupTabSpec('costing', 'สูตรกำไรและต้นทุน', 'dashboard', 'ร้านและต้นทุน'),
  SetupTabSpec('packages', 'แพ็กเกจบุฟเฟต์', 'buffet', 'เมนูและพื้นที่ขาย'),
  SetupTabSpec('addons', 'สินค้าขายเสริม', 'plus', 'เมนูและพื้นที่ขาย'),
  SetupTabSpec('tables', 'โต๊ะในร้าน', 'tables', 'เมนูและพื้นที่ขาย'),
  SetupTabSpec('ingredients', 'วัตถุดิบ', 'box', 'สต็อกและคู่ค้า'),
  SetupTabSpec('suppliers', 'แหล่งซื้อของ', 'stock', 'สต็อกและคู่ค้า'),
  SetupTabSpec('staff', 'พนักงานและสิทธิ์', 'user', 'การเงินและระบบ'),
  SetupTabSpec('payments', 'ช่องทางชำระเงิน', 'receipt', 'การเงินและระบบ'),
  SetupTabSpec('fixedCosts', 'ค่าคงที่รายเดือน', 'bills', 'การเงินและระบบ'),
  SetupTabSpec('expenseTypes', 'ประเภทค่าใช้จ่าย', 'note', 'การเงินและระบบ'),
  SetupTabSpec('theme', 'ธีมและการแสดงผล', 'sun', 'การเงินและระบบ'),
  SetupTabSpec('demo', 'ข้อมูลตัวอย่าง (JSON)', 'clock', 'การเงินและระบบ'),
];

/// Full-width grouped top navigation bar for `/setup`, giving the active
/// section 100% of the page width (matching `/stock`, `/bills`, `/tables`).
class SetupNavSidebar extends StatelessWidget {
  const new({required this.state, required this.onSelectTab, super.key});
  final SetupState state;
  final ValueChanged<String> onSelectTab;

  List<SetupTabSpec> _byGroup(String g) =>
      kSetupTabs.where((x) => x.group == g).toList();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SetupCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space3,
        vertical: AppDimensions.space2_5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildGroupSegment(context, 'ร้านและต้นทุน'),
                _vDivider(t),
                _buildGroupSegment(context, 'เมนูและพื้นที่ขาย'),
                _vDivider(t),
                _buildGroupSegment(context, 'สต็อกและคู่ค้า'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.space2),
            child: Divider(height: 1, thickness: 1, color: t.line),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildGroupSegment(context, 'การเงินและระบบ'),
          ),
        ],
      ),
    );
  }

  Widget _vDivider(AppTokens t) => Container(
    width: 1, height: 44,
    margin: const EdgeInsets.symmetric(horizontal: AppDimensions.space2_5),
    color: t.line,
  );

  Widget _buildGroupSegment(BuildContext context, String groupLabel) {
    final items = _byGroup(groupLabel);
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          groupLabel,
          style: tt.labelSmall?.copyWith(
            color: t.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _buildNavItem(context, items[i]),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildNavItem(BuildContext context, SetupTabSpec item) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final active = state.activeTab == item.id;
    final count = state.itemCountOf(item.id);

    return Material(
      color: active ? t.primary : t.surface2,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: InkWell(
        key: ValueKey('setup-tab-${item.id}'),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        onTap: () => onSelectTab(item.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  item.icon,
                  size: 14,
                  color: active ? t.primaryInk : t.muted,
                ),
                const SizedBox(width: 5),
                Text(
                  item.label,
                  style: tt.bodySmall?.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? t.primaryInk : t.ink,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5.5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? t.primaryInk.withValues(alpha: 0.2)
                          : t.surface,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusPill,
                      ),
                    ),
                    child: Text(
                      '$count',
                      style: tt.labelSmall?.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: active ? t.primaryInk : t.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Theme mode (`light`/`dark`/`system`) selector section.
class SetupThemeSection extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final cubit = context.watch<ThemeCubit?>();
    final state = cubit?.state ?? const ThemeState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'ธีมและการแสดงผล',
          desc: 'เปลี่ยนโหมดสีหน้าจอ มีผลทันทีทุกหน้าจอในเครื่องนี้',
        ),
        const SizedBox(height: AppDimensions.space3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SetupCard(
                key: const ValueKey('setup-theme-section'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('โหมดสีหน้าจอ', style: tt.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'โหมดสว่างเหมาะกับหน้าร้านที่มีแสงจ้า '
                      'โหมดมืดช่วยถนอมสายตาช่วงค่ำ',
                      style: tt.bodySmall?.copyWith(color: t.muted),
                    ),
                    const SizedBox(height: AppDimensions.space3_5),
                    Seg<AppThemeMode>(
                      label: 'โหมดสี',
                      value: state.mode,
                      items: const [
                        SegItem(value: AppThemeMode.light, label: 'สว่าง'),
                        SegItem(value: AppThemeMode.dark, label: 'มืด'),
                        SegItem(
                          value: AppThemeMode.system,
                          label: 'ตามเครื่อง',
                        ),
                      ],
                      onChanged: (m) => cubit?.setMode(m),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.space4),
            Expanded(
              child: SetupCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ตัวอย่างโหมดปัจจุบัน', style: tt.titleMedium),
                    const SizedBox(height: AppDimensions.space3),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.space3_5),
                      decoration: BoxDecoration(
                        color: t.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.line),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('โต๊ะ A1 · กำลังทาน', style: tt.labelSmall),
                              Text('บุฟเฟต์ ฿199', style: tt.titleMedium),
                            ],
                          ),
                          const Pill(
                            tone: PillTone.green,
                            child: Text('อ่านง่าย ชัดเจน'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
