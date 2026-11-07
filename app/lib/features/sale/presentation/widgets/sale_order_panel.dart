import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:app/features/sale/presentation/widgets/sale_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Right-hand `396px` Order Panel (`aside.sale-panel` in `prototype/index.html`).
class SaleOrderPanel extends StatefulWidget {
  const new({
    required this.state,
    required this.staff,
    required this.onSelectTable,
    required this.onOpenNoteModal,
    required this.onOpenRemoveModal,
    super.key,
    this.fullHeight = false,
    this.onOpenPosSlipModal,
  });

  final SaleState state;
  final StaffMember staff;
  final ValueChanged<String> onSelectTable;
  final VoidCallback onOpenNoteModal;
  final ValueChanged<String> onOpenRemoveModal;
  final bool fullHeight;
  final VoidCallback? onOpenPosSlipModal;
  @override
  State<SaleOrderPanel> createState() => _SaleOrderPanelState();
}

class _SaleOrderPanelState extends State<SaleOrderPanel> {
  bool _expandAddPeople = false;
  @override
  void didUpdateWidget(covariant SaleOrderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.tableId != oldWidget.state.tableId) {
      _expandAddPeople = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final staff = widget.staff;
    final fullHeight = widget.fullHeight;
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final bloc = context.read<SaleBloc>();
    final s = state.posState;
    final o = state.openTable;
    final timing = state.effectiveTiming;
    final note = state.effectiveNotes;
    final payOrder = state.payOrder;
    final totalTxt = baht(payOrder.total, payOrder.total % 100 != 0 ? 2 : 0);
    final cartAddons = state.activeAddons
        .where((x) => (state.ad[x.id] ?? 0) > 0)
        .toList();
    final sentRows = state.sentRows;
    final bodyContent = Padding(
      padding: const EdgeInsets.all(AppDimensions.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SalePeopleSection(
            openTable: o,
            pkg: state.activePackage,
            a: state.a,
            c: state.c,
            f: state.f,
            expanded: _expandAddPeople,
            onToggleExpand: (v) => setState(() => _expandAddPeople = v),
            onHeadsChanged: ({a, c, f}) =>
                bloc.add(SaleHeadsChanged(a: a, c: c, f: f)),
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
                onNoteTap: widget.onOpenNoteModal,
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
                icon: AppIcons.forLineKind(
                  l.kind,
                  addonCategory: s.addons
                      .where((a) => a.id == l.key)
                      .map((a) => a.category)
                      .firstOrNull,
                ),
                removeLabel: 'ลบ ${l.name}',
                removeOff: staff.role == 'cashier',
                onRemove: () => widget.onOpenRemoveModal('${l.kind}:${l.key}'),
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
                options: [
                  for (final x in s.tables)
                    DropdownOption(
                      value: x.id,
                      label: 'โต๊ะ ${x.name}',
                      sub: s.openTables[x.id] != null
                          ? 'มีลูกค้า · โต๊ะเปิดอยู่'
                          : 'ว่าง · ${x.seats} ที่นั่ง',
                    ),
                ],
                onChanged: widget.onSelectTable,
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
                          : PillTone.green,
                    )
                  else
                    Flexible(
                      child: Seg<String>(
                        key: const ValueKey('sale-timing-seg'),
                        value: state.timing,
                        items: const [
                          SegItem(
                            value: 'before',
                            label: 'จ่ายก่อนกิน',
                            tone: SegTone.green,
                          ),
                          SegItem(
                            value: 'after',
                            label: 'กินก่อนจ่าย',
                            tone: SegTone.orange,
                          ),
                        ],
                        onChanged: (v) => bloc.add(SaleTimingChanged(v)),
                      ),
                    ),
                  if (o != null && widget.onOpenPosSlipModal != null)
                    Btn(
                      key: const ValueKey('order-panel-pos-slip-btn'),
                      size: BtnSize.sm,
                      icon: 'receipt',
                      label: 'สลิป POS',
                      onPressed: widget.onOpenPosSlipModal,
                    ),
                  Btn(
                    key: const ValueKey('sale-note-btn'),
                    size: BtnSize.sm,
                    icon: 'edit',
                    label: note.isNotEmpty ? 'แก้โน้ต' : 'โน้ต',
                    onPressed: widget.onOpenNoteModal,
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
              if (payOrder.lines.isNotEmpty) ...[
                OrderSummary(
                  shop: s.shop,
                  order: payOrder,
                  noTotal: true,
                  showLines: false,
                ),
                const SizedBox(height: AppDimensions.space2),
              ],
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
              const SizedBox(height: AppDimensions.space3),
              if (timing == 'after') ...[
                Btn(
                  key: const ValueKey('sale-send-round-btn'),
                  label: 'ส่งออเดอร์',
                  kind: state.canSend ? BtnKind.dark : BtnKind.normal,
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
                label:
                    '${timing == 'after' ? 'เช็กบิล' : 'ไปชำระเงิน'} $totalTxt',
                kind: BtnKind.primary,
                size: BtnSize.lg,
                block: true,
                icon: 'receipt',
                disabled: !state.canPay,
                onPressed: () => bloc.add(const SalePaymentStepChanged('pay')),
              ),
            ],
          ),
        ),
      ],
    );
    return Container(
      key: const ValueKey('sale-order-panel'),
      height: fullHeight ? double.infinity : null,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: fullHeight
            ? null
            : BorderRadius.circular(AppDimensions.radiusMd),
        border: fullHeight
            ? Border(left: BorderSide(color: t.line))
            : Border.all(color: t.line),
      ),
      child: fullHeight ? SafeArea(left: false, child: column) : column,
    );
  }
}
