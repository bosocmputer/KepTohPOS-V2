import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:app/features/stock/presentation/widgets/purchase_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Purchase receiving tab (`StockPurchase` in `prototype/index.html:1420-1441`).
class StockPurchaseTab extends StatefulWidget {
  const new({required this.staff, super.key});

  final StaffMember staff;

  @override
  State<StockPurchaseTab> createState() => _StockPurchaseTabState();
}

class _StockPurchaseTabState extends State<StockPurchaseTab> {
  bool _modalOpen = false;
  String? _editId;
  String _modalSupplierId = '';
  String _modalNote = '';
  List<PurchaseModalLineDraft> _modalLines = const <PurchaseModalLineDraft>[];
  PurchaseRecord? _deletingPurchase;

  void _openNew({String? supplierId}) {
    final s = context.read<StockCubit>().state.posState;
    final supId =
        supplierId ?? (s.suppliers.isNotEmpty ? s.suppliers.first.id : '');
    setState(() {
      _modalOpen = true;
      _editId = null;
      _modalSupplierId = supId;
      _modalNote = '';
      _modalLines = <PurchaseModalLineDraft>[
        PurchaseModalLineDraft(
          ingId: s.ingredients.isNotEmpty ? s.ingredients.first.id : '',
        ),
      ];
    });
  }

  void _openCopyLast(String supplierId) {
    final state = context.read<StockCubit>().state;
    final last = state.lastPurchaseOf(supplierId);
    if (last == null) return;
    setState(() {
      _modalOpen = true;
      _editId = null;
      _modalSupplierId = supplierId;
      _modalNote = '';
      _modalLines = last.lines
          .map(
            (l) => PurchaseModalLineDraft(
              ingId: l.ingId,
              qty: fmtQ(l.qty),
              total: l.total == l.total.roundToDouble()
                  ? l.total.toInt().toString()
                  : l.total.toString(),
            ),
          )
          .toList();
    });
  }

  void _openEdit(PurchaseRecord p) {
    if (widget.staff.role == 'cashier') return;
    setState(() {
      _modalOpen = true;
      _editId = p.id;
      _modalSupplierId = p.supplierId;
      _modalNote = p.note;
      _modalLines = p.lines
          .map(
            (l) => PurchaseModalLineDraft(
              ingId: l.ingId,
              qty: fmtQ(l.qty),
              total: l.total == l.total.roundToDouble()
                  ? l.total.toInt().toString()
                  : l.total.toString(),
            ),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final state = context.watch<StockCubit>().state;
    final cubit = context.read<StockCubit>();
    final canManage = widget.staff.role != 'cashier';
    final dayPurchases = state.dayPurchases;

    final deleting = _deletingPurchase;
    final deletingTotal =
        deleting?.lines.fold<double>(0, (s, l) => s + l.total) ?? 0;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'รับของเข้า',
                desc: 'แตะ เหมือนครั้งก่อน แล้วแก้เฉพาะตัวเลขที่เปลี่ยน',
                actions: [
                  Btn(
                    key: const ValueKey('purchase-add-btn'),
                    kind: BtnKind.primary,
                    icon: 'plus',
                    label: 'บันทึกการซื้อ',
                    onPressed: _openNew,
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space4),
              Wrap(
                spacing: AppDimensions.space3,
                runSpacing: AppDimensions.space3,
                children: [
                  for (final sup in state.posState.suppliers)
                    _SupplierShortcutCard(
                      supplier: sup,
                      lastPurchase: state.lastPurchaseOf(sup.id),
                      onCopyLast: () => _openCopyLast(sup.id),
                      onNew: () => _openNew(supplierId: sup.id),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.space5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ซื้อเข้าวันที่ ${thDateShort(state.selectedDate)}',
                    style: tt.titleLarge?.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${dayPurchases.length} บิล · '
                    'รวม ${baht(state.dayPurchasesTotal)}',
                    key: const ValueKey('purchase-day-summary'),
                    style: tt.titleMedium?.copyWith(
                      color: t.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space3),
              PosDataTable<PurchaseRecord>(
                rows: dayPurchases,
                empty: const Empty(
                  title: 'ยังไม่มีการรับของเข้าวันนี้',
                  text: 'เลือกแหล่งซื้อด้านบน แล้วกด เหมือนครั้งก่อน',
                ),
                columns: [
                  DataTableCol<PurchaseRecord>(
                    key: 'time',
                    label: 'เวลา',
                    cellBuilder: (context, p) => Text(
                      thTime(p.at),
                      style: tt.bodyMedium?.copyWith(color: t.ink),
                    ),
                  ),
                  DataTableCol<PurchaseRecord>(
                    key: 'supplier',
                    label: 'แหล่งซื้อ',
                    flex: 2,
                    cellBuilder: (context, p) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.supplierNameOf(p.supplierId),
                          style: tt.bodyMedium?.copyWith(
                            color: t.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (p.note.isNotEmpty)
                          Text(
                            p.note,
                            style: tt.labelSmall?.copyWith(color: t.muted),
                          ),
                      ],
                    ),
                  ),
                  DataTableCol<PurchaseRecord>(
                    key: 'items',
                    label: 'รายการวัตถุดิบ',
                    flex: 4,
                    cellBuilder: (context, p) => Wrap(
                      spacing: AppDimensions.space1_5,
                      runSpacing: AppDimensions.space1,
                      children: [
                        for (final l in p.lines)
                          Pill(
                            label:
                                '${state.ingredientOf(l.ingId)?.name ?? "?"} '
                                '${fmtQ(l.qty)} '
                                '${state.ingredientOf(l.ingId)?.unit ?? ""} · '
                                '${fmt(l.total)}฿',
                          ),
                      ],
                    ),
                  ),
                  DataTableCol<PurchaseRecord>(
                    key: 'total',
                    label: 'ยอดรวม',
                    flex: 2,
                    align: ColAlign.right,
                    cellBuilder: (context, p) {
                      final sum = p.lines.fold<double>(
                        0,
                        (acc, l) => acc + l.total,
                      );
                      return Text(
                        baht(sum),
                        textAlign: TextAlign.right,
                        style: tt.bodyMedium?.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                  if (canManage)
                    DataTableCol<PurchaseRecord>(
                      key: 'actions',
                      label: 'จัดการ',
                      flex: 2,
                      align: ColAlign.right,
                      cellBuilder: (context, p) => Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Btn(
                            key: ValueKey('purchase-edit-${p.id}'),
                            size: BtnSize.sm,
                            icon: 'edit',
                            semanticLabel: 'แก้ไข',
                            onPressed: () => _openEdit(p),
                          ),
                          const SizedBox(width: AppDimensions.space1_5),
                          Btn(
                            key: ValueKey('purchase-delete-${p.id}'),
                            size: BtnSize.sm,
                            kind: BtnKind.danger,
                            icon: 'trash',
                            semanticLabel: 'ลบ',
                            onPressed: () =>
                                setState(() => _deletingPurchase = p),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_modalOpen)
          PurchaseModal(
            state: state,
            editId: _editId,
            initialDate: state.selectedDate,
            initialSupplierId: _modalSupplierId,
            initialNote: _modalNote,
            initialLines: _modalLines,
            onClose: () => setState(() => _modalOpen = false),
            onSave:
                ({
                  required date,
                  required supplierId,
                  required note,
                  required lines,
                  editId,
                }) {
                  final ok = cubit.submitPurchase(
                    date: date,
                    supplierId: supplierId,
                    note: note,
                    lines: lines,
                    staff: widget.staff,
                    editId: editId,
                  );
                  if (ok) {
                    setState(() => _modalOpen = false);
                  }
                },
          ),
        if (deleting != null)
          RootOverlayBox(
            child: Material(
              color: t.scrim,
              child: SafeArea(
                child: Confirm(
                  title: 'ลบบิลซื้อของนี้?',
                  text:
                      '${state.supplierNameOf(deleting.supplierId)} · '
                      '${baht(deletingTotal)}',
                  yesLabel: 'ลบ',
                  danger: true,
                  onNo: () => setState(() => _deletingPurchase = null),
                  onYes: () {
                    setState(() => _deletingPurchase = null);
                    cubit.removePurchase(
                      purchaseId: deleting.id,
                      staff: widget.staff,
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SupplierShortcutCard extends StatelessWidget {
  const new({
    required this.supplier,
    required this.lastPurchase,
    required this.onCopyLast,
    required this.onNew,
  });

  final SupplierItem supplier;
  final PurchaseRecord? lastPurchase;
  final VoidCallback onCopyLast;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final lastTotal =
        lastPurchase?.lines.fold<double>(0, (s, l) => s + l.total) ?? 0;

    return Container(
      width: 300,
      padding: const EdgeInsets.all(AppDimensions.space4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.r),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supplier.name,
            style: tt.titleMedium?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.space1),
          Text(
            lastPurchase != null
                ? 'ครั้งก่อน ${thDateShort(lastPurchase!.date)} · '
                      '${lastPurchase!.lines.length} รายการ · '
                      '${baht(lastTotal)}'
                : 'ยังไม่เคยซื้อจากที่นี่',
            style: tt.bodySmall?.copyWith(color: t.muted),
          ),
          const SizedBox(height: AppDimensions.space3),
          Row(
            children: [
              Btn(
                key: ValueKey('purchase-copy-sup-${supplier.id}'),
                kind: BtnKind.primary,
                size: BtnSize.sm,
                icon: 'copy',
                label: 'เหมือนครั้งก่อน',
                disabled: lastPurchase == null,
                onPressed: onCopyLast,
              ),
              const SizedBox(width: AppDimensions.space2),
              Btn(
                key: ValueKey('purchase-new-sup-${supplier.id}'),
                size: BtnSize.sm,
                icon: 'plus',
                label: 'รายการใหม่',
                onPressed: onNew,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
