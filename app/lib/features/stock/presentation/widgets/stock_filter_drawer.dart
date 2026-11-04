import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:flutter/material.dart';

/// Right-side slide-over filter drawer for the `/stock` Balance tab
/// (`design/figma/filter_history_supply.png`), built on the shared
/// [RightSheetDrawer].
class StockFilterDrawer extends StatelessWidget {
  const new({
    required this.state,
    required this.onToggleLocation,
    required this.onStatusChanged,
    required this.onClear,
    required this.onClose,
    super.key,
  });

  final StockState state;
  final ValueChanged<String> onToggleLocation;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;

    return RightSheetDrawer(
      drawerKey: const ValueKey('stock-filter-drawer'),
      closeButtonKey: const ValueKey('stock-filter-close-btn'),
      title: 'ตัวกรอง',
      onClose: onClose,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Btn(
            key: const ValueKey('stock-filter-apply-btn'),
            kind: BtnKind.primary,
            block: true,
            label: 'ดูผล (${state.filteredBalanceRows.length} รายการ)',
            onPressed: onClose,
          ),
          const SizedBox(height: AppDimensions.space2),
          Btn(
            key: const ValueKey('stock-filter-clear-btn'),
            block: true,
            label: 'ล้างตัวกรอง',
            disabled: state.activeFilterCount == 0,
            onPressed: onClear,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'สถานที่จัดเก็บ',
            style: tt.titleMedium?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.space2_5),
          for (final entry in kLocations.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space2),
              child: _LocationCheckTile(
                key: ValueKey('stock-filter-loc-${entry.key}'),
                label: entry.value,
                checked: state.locationFilters.contains(entry.key),
                onTap: () => onToggleLocation(entry.key),
              ),
            ),
          const SizedBox(height: AppDimensions.space4),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space4),
          Text(
            'สถานะคงเหลือ',
            style: tt.titleMedium?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.space2_5),
          Seg<String>(
            key: const ValueKey('stock-filter-status-seg'),
            value: state.statusFilter,
            onChanged: onStatusChanged,
            items: const <SegItem<String>>[
              SegItem(value: 'all', label: 'ทั้งหมด'),
              SegItem(value: 'ok', label: 'พอ'),
              SegItem(value: 'low', label: 'ใกล้หมด'),
              SegItem(value: 'out', label: 'หมด'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationCheckTile extends StatelessWidget {
  const new({
    required this.label,
    required this.checked,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space3,
          vertical: AppDimensions.space2_5,
        ),
        decoration: BoxDecoration(
          color: checked ? t.primarySoft : t.surface2,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: checked ? t.primary : t.line),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: checked ? t.primary : t.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: checked ? t.primary : t.line,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Center(
                      child: AppIcon(
                        'check',
                        size: 13,
                        color: AppRawTokens.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppDimensions.space2_5),
            Expanded(
              child: Text(
                label,
                style: tt.bodyMedium?.copyWith(
                  color: t.ink,
                  fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
