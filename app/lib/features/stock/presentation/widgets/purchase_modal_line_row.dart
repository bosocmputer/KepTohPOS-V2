import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:flutter/material.dart';

/// Editable line inside `PurchaseModal`.
class PurchaseModalLineDraft {
  const new({required this.ingId, this.qty = '', this.total = ''});

  final String ingId;
  final String qty;
  final String total;

  PurchaseModalLineDraft copyWith({
    String? ingId,
    String? qty,
    String? total,
  }) => PurchaseModalLineDraft(
    ingId: ingId ?? this.ingId,
    qty: qty ?? this.qty,
    total: total ?? this.total,
  );
}

/// Single ingredient line row inside `PurchaseModal`.
class PurchaseModalLineRow extends StatelessWidget {
  const new({
    required this.index,
    required this.line,
    required this.state,
    required this.onChanged,
    required this.onDelete,
    super.key,
  });

  final int index;
  final PurchaseModalLineDraft line;
  final StockState state;
  final ValueChanged<PurchaseModalLineDraft> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = state.posState;
    final ing = state.ingredientOf(line.ingId);
    final q = double.tryParse(line.qty.trim()) ?? 0;
    final tot = double.tryParse(line.total.trim()) ?? 0;
    final unitHint = q > 0 && tot > 0
        ? '${fmt(tot / q, 2)} ฿/${ing?.unit ?? "หน่วย"}'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space2_5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Field(
              label: index == 0 ? 'รายการ' : '',
              child: Dropdown<String>(
                key: ValueKey('purchase-line-ing-$index'),
                value: line.ingId,
                placeholder: 'เลือกวัตถุดิบ',
                onChanged: (v) => onChanged(line.copyWith(ingId: v)),
                options: [
                  const DropdownOption<String>(
                    value: '',
                    label: 'เลือกวัตถุดิบ',
                  ),
                  for (final x in s.ingredients)
                    DropdownOption<String>(
                      value: x.id,
                      label: '${x.name} (${x.unit})',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space2_5),
          Expanded(
            flex: 2,
            child: Field(
              label: index == 0 ? 'จำนวน' : '',
              child: AppTextInput(
                key: ValueKey('purchase-line-qty-$index'),
                value: line.qty,
                placeholder: '0',
                suffixText: ing?.unit,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) => onChanged(line.copyWith(qty: v)),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space2_5),
          Expanded(
            flex: 3,
            child: Field(
              label: index == 0 ? 'ยอดเงิน (บาท)' : '',
              child: AppTextInput(
                key: ValueKey('purchase-line-total-$index'),
                value: line.total,
                placeholder: '0',
                suffixText: unitHint ?? '฿',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) => onChanged(line.copyWith(total: v)),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space2),
          Field(
            label: index == 0 ? ' ' : '',
            child: Btn(
              key: ValueKey('purchase-line-del-$index'),
              kind: BtnKind.ghost,
              icon: 'trash',
              semanticLabel: 'ลบบรรทัด',
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
