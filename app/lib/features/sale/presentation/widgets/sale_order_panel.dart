import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:app/features/sale/presentation/widgets/sale_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Right-hand `396px` Order Panel (`aside.sale-panel` in `prototype/index.html`
/// & `design/figma/cashier.png`).
class SaleOrderPanel extends StatelessWidget {
  const new({
    required this.state,
    required this.staff,
    required this.onSelectTable,
    required this.onOpenNoteModal,
    required this.onOpenRemoveModal,
    super.key,
    this.fullHeight = false,
    this.selectedMethodId,
    this.onSelectMethod,
    this.onPayPressed,
  });

  final SaleState state;
  final StaffMember staff;
  final ValueChanged<String> onSelectTable;
  final VoidCallback onOpenNoteModal;
  final ValueChanged<String> onOpenRemoveModal;
  final bool fullHeight;
  final String? selectedMethodId;
  final ValueChanged<String>? onSelectMethod;
  final VoidCallback? onPayPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final bloc = context.read<SaleBloc>();
    final s = state.posState;
    final o = state.openTable;
    final pkg = state.activePackage;
    final timing = state.effectiveTiming;
    final note = state.effectiveNotes;
    final payOrder = state.payOrder;
    final totalTxt = baht(payOrder.total, payOrder.total % 1 != 0 ? 2 : 0);
    final sentRows = state.sentRows;
    final canVoid = staff.role != 'cashier';
    final methodId = selectedMethodId ?? state.activePaymentMethod?.id ?? 'pm1';

    final tableOpts = s.tables.map((x) {
      final ot = s.openTables[x.id];
      final sub = ot != null
          ? 'มีลูกค้า${tableDue(s, ot) > 0 ? " · รอชำระ" : ""}'
          : 'ว่าง · ${x.seats} ที่นั่ง';
      return DropdownOption<String>(
        value: x.id,
        label: 'โต๊ะ ${x.name}',
        sub: sub,
      );
    }).toList();

    final cartAddons = state.activeAddons
        .where((x) => (state.ad[x.id] ?? 0) > 0)
        .toList();

    final bodyContent = Padding(
      padding: const EdgeInsets.all(AppDimensions.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${o != null ? "เพิ่มคน (ถ้ามี)" : "จำนวนลูกค้า"}'
            '${pkg != null ? " · ${pkg.name}" : ""}',
            style: tt.titleMedium?.copyWith(color: t.ink),
          ),
          const SizedBox(height: AppDimensions.space2),
          PeopleRow(
            stepperKey: const ValueKey('people-stepper-a'),
            label: 'ผู้ใหญ่',
            sub: pkg != null ? baht(pkg.adultPrice) : '-',
            value: state.a,
            onChanged: (v) => bloc.add(SaleHeadsChanged(a: v)),
          ),
          PeopleRow(
            stepperKey: const ValueKey('people-stepper-c'),
            label: 'เด็ก',
            sub: pkg != null
                ? '${baht(pkg.childPrice)} · ${pkg.childRule}'
                : '-',
            value: state.c,
            onChanged: (v) => bloc.add(SaleHeadsChanged(c: v)),
          ),
          PeopleRow(
            stepperKey: const ValueKey('people-stepper-f'),
            label: 'เด็กเล็ก',
            sub: pkg != null ? pkg.freeRule : '-',
            value: state.f,
            onChanged: (v) => bloc.add(SaleHeadsChanged(f: v)),
          ),
          if (cartAddons.isNotEmpty) ...[
            Divider(color: t.line, height: AppDimensions.space6),
            Text(
              timing == 'after'
                  ? 'รายการใหม่ (ยังไม่ส่ง)'
                  : 'ขายเสริม · เครื่องดื่ม',
              style: tt.titleMedium?.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppDimensions.space1_5),
            for (final x in cartAddons)
              OrderLine(
                name: x.name,
                sub: baht(x.price),
                qty: state.ad[x.id] ?? 0,
                icon: AppIcons.forCategory(x.category),
                onNoteTap: onOpenNoteModal,
                onChanged: (q) =>
                    bloc.add(SaleAddonQtyChanged(addonId: x.id, qty: q)),
              ),
          ],
          if (sentRows.isNotEmpty) ...[
            Divider(color: t.line, height: AppDimensions.space6),
            Text(
              'ส่งออเดอร์แล้ว · รอชำระ',
              style: tt.titleMedium?.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppDimensions.space1_5),
            for (final l in sentRows)
              OrderLine(
                key: ValueKey('sent-line-${l.kind}-${l.key}'),
                name: l.name,
                sub: l.price > 0 ? baht(l.price) : 'ฟรี',
                qty: l.qty,
                icon: l.kind == 'pkg' ? 'package' : 'drink',
                removeLabel: 'ลบ ${l.name}',
                removeOff: !canVoid,
                onRemove: () => onOpenRemoveModal('${l.kind}:${l.key}'),
              ),
          ],
        ],
      ),
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: fullHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Dropdown<String>(
                key: const ValueKey('sale-table-dropdown'),
                label: 'เลือกโต๊ะ',
                value: state.tableId,
                options: tableOpts,
                onChanged: onSelectTable,
              ),
              const SizedBox(height: AppDimensions.space3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (o != null)
                    Pill(
                      label: timing == 'after' ? 'กินก่อนจ่าย' : 'จ่ายก่อนกิน',
                      tone: timing == 'after'
                          ? PillTone.orange
                          : PillTone.neutral,
                    )
                  else
                    Flexible(
                      child: Seg<String>(
                        key: const ValueKey('sale-timing-seg'),
                        value: state.timing,
                        items: const [
                          SegItem(value: 'before', label: 'จ่ายก่อนกิน'),
                          SegItem(value: 'after', label: 'กินก่อนจ่าย'),
                        ],
                        onChanged: (v) => bloc.add(SaleTimingChanged(v)),
                      ),
                    ),
                  const SizedBox(width: AppDimensions.space2),
                  Btn(
                    key: const ValueKey('sale-note-btn'),
                    size: BtnSize.sm,
                    icon: 'edit',
                    label: note.isNotEmpty ? 'แก้โน้ต' : 'โน้ต',
                    onPressed: onOpenNoteModal,
                  ),
                ],
              ),
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.space2),
                  child: Text(
                    '✎ $note',
                    style: tt.labelSmall?.copyWith(color: t.muted),
                  ),
                ),
            ],
          ),
        ),
        Divider(color: t.line, height: 1),
        if (fullHeight)
          Expanded(child: SingleChildScrollView(child: bodyContent))
        else
          bodyContent,
        Divider(color: t.line, height: 1),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrderSummary(
                shop: s.shop,
                order: payOrder,
                noTotal: true,
                showLines: false,
              ),
              const SizedBox(height: AppDimensions.space2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    timing == 'after' && state.due > 0
                        ? 'ยอดชำระ (รวมที่ส่งแล้ว)'
                        : 'ยอดชำระ',
                    style: tt.bodyMedium?.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    key: const ValueKey('sale-total-amount'),
                    totalTxt,
                    style: tt.displayLarge?.copyWith(
                      color: t.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space2),
              PaymentPicker(
                methods: s.payments,
                value: methodId,
                onChanged:
                    onSelectMethod ??
                    (id) => bloc.add(SalePaymentMethodSelected(id)),
              ),
              const SizedBox(height: AppDimensions.space3),
              if (timing == 'after') ...[
                Btn(
                  key: const ValueKey('sale-send-round-btn'),
                  label: 'ส่งออเดอร์',
                  size: BtnSize.lg,
                  block: true,
                  icon: 'plus',
                  disabled: !state.canSend,
                  onPressed: () => bloc.add(SaleRoundSent(staff: staff)),
                ),
                const SizedBox(height: AppDimensions.space2),
              ],
              Btn(
                key: const ValueKey('sale-pay-btn'),
                label: timing == 'after'
                    ? 'เช็กบิล $totalTxt'
                    : 'ไปชำระเงิน $totalTxt',
                kind: BtnKind.primary,
                size: BtnSize.lg,
                block: true,
                icon: 'receipt',
                disabled: !state.canPay,
                onPressed:
                    onPayPressed ??
                    () => bloc.add(const SalePaymentStepChanged('pay')),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      key: const ValueKey('sale-order-panel'),
      height: fullHeight ? double.infinity : null,
      decoration: fullHeight
          ? BoxDecoration(
              color: t.surface,
              border: Border(left: BorderSide(color: t.line)),
            )
          : BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: t.line),
            ),
      child: fullHeight ? SafeArea(left: false, child: column) : column,
    );
  }
}
