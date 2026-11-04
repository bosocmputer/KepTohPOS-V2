import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:flutter/material.dart';

/// Right-side slide-over filter panel for `BillsPage`
/// (`design/figma/filter_history_supply.png` & `BillsView` in `index.html`).
class BillsFilterDrawer extends StatelessWidget {
  const new({
    required this.state,
    required this.onToggleMethod,
    required this.onStatusChanged,
    required this.onClear,
    required this.onClose,
    super.key,
  });

  final BillsState state;
  final ValueChanged<String> onToggleMethod;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final payments = state.posState.payments;

    return RightSheetDrawer(
      drawerKey: const ValueKey('bills-filter-drawer'),
      closeButtonKey: const ValueKey('bills-filter-close-btn'),
      title: 'ตัวกรอง',
      onClose: onClose,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Btn(
            key: const ValueKey('filter-apply-btn'),
            kind: BtnKind.primary,
            block: true,
            label: 'ดูผล (${state.filteredBills.length} บิล)',
            onPressed: onClose,
          ),
          const SizedBox(height: AppDimensions.space2),
          Btn(
            key: const ValueKey('filter-clear-btn'),
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
            'วิธีชำระเงิน',
            style: tt.titleMedium?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.space2_5),
          for (final pm in payments)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space2),
              child: _MethodCheckboxTile(
                key: ValueKey('filter-method-${pm.id}'),
                label: pm.name,
                checked: state.selectedMethodIds.contains(pm.id),
                onTap: () => onToggleMethod(pm.id),
              ),
            ),
          const SizedBox(height: AppDimensions.space4),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space4),
          Text(
            'สถานะบิล',
            style: tt.titleMedium?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.space2_5),
          Seg<String>(
            key: const ValueKey('filter-status-seg'),
            value: state.statusFilter,
            onChanged: onStatusChanged,
            items: const <SegItem<String>>[
              SegItem(value: 'all', label: 'ทั้งหมด'),
              SegItem(value: 'ok', label: 'ปกติ'),
              SegItem(value: 'void', label: 'ยกเลิก'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodCheckboxTile extends StatelessWidget {
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
