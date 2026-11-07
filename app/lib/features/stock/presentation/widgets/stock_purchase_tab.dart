import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:app/features/stock/presentation/widgets/purchase_modal.dart';
import 'package:app/features/stock/presentation/widgets/stock_purchase_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/stock/presentation/widgets/stock_purchase_widgets.dart';

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

  static List<PurchaseModalLineDraft> _linesFromRecord(PurchaseRecord r) => r
      .lines
      .map(
        (l) => PurchaseModalLineDraft(
          ingId: l.ingId,
          qty: fmtQ(l.qty),
          total: bahtInputText(l.total),
        ),
      )
      .toList();

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
    final last = context.read<StockCubit>().state.lastPurchaseOf(supplierId);
    if (last == null) return;
    setState(() {
      _modalOpen = true;
      _editId = null;
      _modalSupplierId = supplierId;
      _modalNote = '';
      _modalLines = _linesFromRecord(last);
    });
  }

  void _openEdit(PurchaseRecord p) {
    if (widget.staff.role == 'cashier') return;
    setState(() {
      _modalOpen = true;
      _editId = p.id;
      _modalSupplierId = p.supplierId;
      _modalNote = p.note;
      _modalLines = _linesFromRecord(p);
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final availW = constraints.maxWidth;
                  final cols = availW >= 1200 ? 4 : (availW >= 560 ? 2 : 1);
                  const gap = AppDimensions.space3;
                  final cardW = (availW - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final sup in state.posState.suppliers)
                        SupplierShortcutCard(
                          width: cardW,
                          supplier: sup,
                          lastPurchase: state.lastPurchaseOf(sup.id),
                          showCosts: state.showCosts,
                          onCopyLast: () => _openCopyLast(sup.id),
                          onNew: () => _openNew(supplierId: sup.id),
                        ),
                    ],
                  );
                },
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
                    'รวม ${state.costText(baht(state.dayPurchasesTotal))}',
                    key: const ValueKey('purchase-day-summary'),
                    style: tt.titleMedium?.copyWith(
                      color: t.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space3),
              PurchaseBillsTable(
                rows: dayPurchases,
                state: state,
                canManage: canManage,
                onEdit: _openEdit,
                onDelete: (p) => setState(() => _deletingPurchase = p),
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
                }) async {
                  final ok = await cubit.submitPurchase(
                    date: date,
                    supplierId: supplierId,
                    note: note,
                    lines: lines,
                    staff: widget.staff,
                    editId: editId,
                  );
                  if (ok && mounted) {
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
                      '${state.costText(baht(deletingTotal))}',
                  yesLabel: 'ลบ',
                  danger: true,
                  onNo: () => setState(() => _deletingPurchase = null),
                  onYes: () async {
                    setState(() => _deletingPurchase = null);
                    await cubit.removePurchase(
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
