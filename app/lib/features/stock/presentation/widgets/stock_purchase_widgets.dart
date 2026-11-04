import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:flutter/material.dart';

/// Supplier quick-receive card (`sup-card` in `prototype/index.html:1426`).
class SupplierShortcutCard extends StatelessWidget {
  const new({
    required this.supplier,
    required this.lastPurchase,
    required this.onCopyLast,
    required this.onNew,
    super.key,
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

/// Daily purchase bills table in `StockPurchaseTab`.
class PurchaseBillsTable extends StatelessWidget {
  const new({
    required this.rows,
    required this.state,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final List<PurchaseRecord> rows;
  final StockState state;
  final bool canManage;
  final ValueChanged<PurchaseRecord> onEdit;
  final ValueChanged<PurchaseRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;

    return PosDataTable<PurchaseRecord>(
      rows: rows,
      empty: const Empty(
        title: 'ยังไม่มีการรับของเข้าวันนี้',
        text: 'เลือกแหล่งซื้อด้านบน แล้วกด เหมือนครั้งก่อน',
      ),
      columns: [
        DataTableCol<PurchaseRecord>(
          key: 'time',
          label: 'เวลา',
          cellBuilder: (context, p) =>
              Text(thTime(p.at), style: tt.bodyMedium?.copyWith(color: t.ink)),
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
                Text(p.note, style: tt.labelSmall?.copyWith(color: t.muted)),
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
            final sum = p.lines.fold<double>(0, (acc, l) => acc + l.total);
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
                  onPressed: () => onEdit(p),
                ),
                const SizedBox(width: AppDimensions.space1_5),
                Btn(
                  key: ValueKey('purchase-delete-${p.id}'),
                  size: BtnSize.sm,
                  kind: BtnKind.danger,
                  icon: 'trash',
                  semanticLabel: 'ลบ',
                  onPressed: () => onDelete(p),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
