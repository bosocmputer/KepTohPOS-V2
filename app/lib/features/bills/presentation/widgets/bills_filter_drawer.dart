import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:flutter/material.dart';

/// Maps payment method type or label to its icon name (`cash`, `qr`, `bank`).
String billsMethodIcon(String text) => text.contains('เงินสด') || text == 'cash'
    ? 'cash'
    : (text.contains('QR') || text.contains('พร้อมเพย์') || text == 'qr'
          ? 'qr'
          : 'bank');

/// Summary bar showing daily sales broken down by payment channel.
class BillsMethodSummaryBar extends StatelessWidget {
  const new({required this.salesByMethod, super.key});

  final Map<String, double> salesByMethod;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('bills-method-summary'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space4,
        vertical: AppDimensions.space2_5,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.r),
        border: Border.all(color: t.line),
      ),
      child: Wrap(
        spacing: AppDimensions.space2_5,
        runSpacing: AppDimensions.space2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'แยกตามช่องทาง:',
            style: tt.labelMedium?.copyWith(color: t.muted),
          ),
          for (final entry in salesByMethod.entries)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space2_5,
                vertical: AppDimensions.space1,
              ),
              decoration: BoxDecoration(
                color: t.surface2,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: t.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(billsMethodIcon(entry.key), size: 14, color: t.muted),
                  const SizedBox(width: AppDimensions.space1_5),
                  Text(
                    '${entry.key}: ',
                    style: tt.bodySmall?.copyWith(color: t.muted),
                  ),
                  Text(
                    baht(entry.value),
                    style: tt.bodyMedium?.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Active filter chips + 1-tap reset button shown above the bills table.
class BillsActiveFiltersRow extends StatelessWidget {
  const new({required this.state, required this.onClear, super.key});

  final BillsState state;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppDimensions.space2,
    runSpacing: AppDimensions.space2,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (state.statusFilter != 'all')
        Pill(
          label: state.statusFilter == 'ok' ? 'สถานะ: ปกติ' : 'สถานะ: ยกเลิก',
          tone: state.statusFilter == 'ok' ? PillTone.green : PillTone.red,
        ),
      for (final pm in state.posState.payments.where(
        (p) => state.selectedMethodIds.contains(p.id),
      ))
        Pill(label: pm.name, tone: PillTone.orange),
      Btn(
        size: BtnSize.sm,
        kind: BtnKind.ghost,
        icon: 'x',
        label: 'ล้างตัวกรอง',
        onPressed: onClear,
      ),
    ],
  );
}

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
                icon: pm.type == 'cash'
                    ? 'cash'
                    : (pm.type == 'qr' ? 'qr' : 'bank'),
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
              SegItem(value: 'ok', label: 'ปกติ', tone: SegTone.green),
              SegItem(value: 'void', label: 'ยกเลิก', tone: SegTone.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodCheckboxTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.checked,
    required this.onTap,
    super.key,
  });

  final String icon;
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
            AppIcon(icon, size: 16, color: checked ? t.primary : t.muted),
            const SizedBox(width: AppDimensions.space2),
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
