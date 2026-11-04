import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:flutter/material.dart';

/// Editable line inside [PurchaseModal].
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

/// Modal dialog for recording or editing a purchase bill
/// (`PurchaseModal` in `prototype/index.html:1313-1346`).
class PurchaseModal extends StatefulWidget {
  const new({
    required this.state,
    required this.initialDate,
    required this.initialSupplierId,
    required this.initialLines,
    required this.onSave,
    required this.onClose,
    super.key,
    this.editId,
    this.initialNote = '',
  });

  final StockState state;
  final String initialDate;
  final String initialSupplierId;
  final List<PurchaseModalLineDraft> initialLines;
  final String? editId;
  final String initialNote;
  final void Function({
    required String date,
    required String supplierId,
    required String note,
    required List<PurchaseLine> lines,
    String? editId,
  })
  onSave;
  final VoidCallback onClose;

  @override
  State<PurchaseModal> createState() => _PurchaseModalState();
}

class _PurchaseModalState extends State<PurchaseModal> {
  late String _date = widget.initialDate;
  late String _supplierId = widget.initialSupplierId;
  late String _note = widget.initialNote;
  late List<PurchaseModalLineDraft> _lines = List<PurchaseModalLineDraft>.from(
    widget.initialLines,
  );
  String _error = '';

  double get _total => _lines.fold<double>(
    0,
    (sum, l) => sum + (double.tryParse(l.total.trim()) ?? 0),
  );

  void _copyLast() {
    final last = widget.state.lastPurchaseOf(
      _supplierId,
      excludeId: widget.editId,
    );
    if (last == null) {
      setState(() => _error = 'ยังไม่เคยซื้อจากร้านนี้');
      return;
    }
    setState(() {
      _error = '';
      _lines = last.lines
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

  void _handleSave() {
    final parsed = <PurchaseLine>[];
    for (final l in _lines) {
      final q = double.tryParse(l.qty.trim()) ?? 0;
      final t = double.tryParse(l.total.trim()) ?? 0;
      if (l.ingId.isNotEmpty && q > 0) {
        parsed.add(PurchaseLine(ingId: l.ingId, qty: q, total: t));
      }
    }
    if (parsed.isEmpty) {
      setState(() => _error = 'ใส่อย่างน้อย 1 รายการที่มีจำนวนมากกว่า 0');
      return;
    }
    widget.onSave(
      date: _date,
      supplierId: _supplierId,
      note: _note,
      lines: parsed,
      editId: widget.editId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final s = widget.state.posState;

    return RootOverlayBox(
      child: Material(
        key: const ValueKey('purchase-modal'),
        color: t.scrim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space4),
            child: Modal(
              wide: true,
              title: widget.editId == null ? 'รับของเข้า' : 'แก้ไขบิลซื้อของ',
              sub: 'ใส่จำนวนและยอดเงินตามบิล ระบบคิดราคาต่อหน่วยให้',
              onClose: widget.onClose,
              footerLeading: Text(
                'รวม ${baht(_total, 2)}',
                key: const ValueKey('purchase-modal-total'),
                style: tt.titleLarge?.copyWith(
                  color: t.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              footer: [
                Btn(
                  key: const ValueKey('purchase-modal-cancel-btn'),
                  label: 'ยกเลิก',
                  onPressed: widget.onClose,
                ),
                Btn(
                  key: const ValueKey('purchase-modal-save-btn'),
                  kind: BtnKind.primary,
                  icon: 'check',
                  label: 'บันทึก',
                  onPressed: _handleSave,
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Field(
                          label: 'วันที่ซื้อ',
                          child: Dropdown<String>(
                            key: const ValueKey('purchase-modal-date'),
                            value: _date,
                            onChanged: (v) => setState(() => _date = v),
                            options: [
                              for (final d in widget.state.availableDates)
                                DropdownOption<String>(
                                  value: d,
                                  label: thDate(d),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space3),
                      Expanded(
                        child: Field(
                          label: 'ซื้อจาก',
                          child: Dropdown<String>(
                            key: const ValueKey('purchase-modal-supplier'),
                            value: _supplierId,
                            onChanged: (v) => setState(() => _supplierId = v),
                            options: [
                              for (final sup in s.suppliers)
                                DropdownOption<String>(
                                  value: sup.id,
                                  label: sup.name,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space3),
                      Expanded(
                        child: Field(
                          label: 'หมายเหตุ',
                          child: AppTextInput(
                            key: const ValueKey('purchase-modal-note'),
                            value: _note,
                            placeholder: 'เช่น ตลาดเช้า',
                            onChanged: (v) => setState(() => _note = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space3),
                  Row(
                    children: [
                      Btn(
                        key: const ValueKey('purchase-modal-copy-last-btn'),
                        icon: 'copy',
                        size: BtnSize.sm,
                        label: 'ใช้รายการเดิมจากครั้งก่อน',
                        onPressed: _copyLast,
                      ),
                      const SizedBox(width: AppDimensions.space2_5),
                      Expanded(
                        child: Text(
                          'ร้านหมูกระทะซื้อของซ้ำทุกวัน '
                          'กดครั้งเดียวแล้วแก้เฉพาะตัวเลข',
                          style: tt.bodySmall?.copyWith(color: t.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space3),
                  for (var i = 0; i < _lines.length; i++)
                    _buildLineRow(context, i, _lines[i], s),
                  const SizedBox(height: AppDimensions.space2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Btn(
                      key: const ValueKey('purchase-modal-add-line-btn'),
                      icon: 'plus',
                      size: BtnSize.sm,
                      label: 'เพิ่มบรรทัด',
                      onPressed: () => setState(() {
                        _lines.add(const PurchaseModalLineDraft(ingId: ''));
                      }),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.space2),
                    Text(
                      _error,
                      style: tt.bodySmall?.copyWith(
                        color: t.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLineRow(
    BuildContext context,
    int index,
    PurchaseModalLineDraft line,
    PosState s,
  ) {
    final ing = widget.state.ingredientOf(line.ingId);
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
                onChanged: (v) => setState(() {
                  _lines[index] = line.copyWith(ingId: v);
                }),
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
              hint: ing?.unit,
              child: AppTextInput(
                key: ValueKey('purchase-line-qty-$index'),
                value: line.qty,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) => setState(() {
                  _lines[index] = line.copyWith(qty: v);
                }),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space2_5),
          Expanded(
            flex: 3,
            child: Field(
              label: index == 0 ? 'ยอดเงิน (บาท)' : '',
              hint: unitHint,
              child: AppTextInput(
                key: ValueKey('purchase-line-total-$index'),
                value: line.total,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) => setState(() {
                  _lines[index] = line.copyWith(total: v);
                }),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space2),
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 25 : 0),
            child: Btn(
              key: ValueKey('purchase-line-del-$index'),
              kind: BtnKind.ghost,
              icon: 'trash',
              semanticLabel: 'ลบบรรทัด',
              onPressed: () => setState(() {
                if (_lines.length > 1) {
                  _lines.removeAt(index);
                }
              }),
            ),
          ),
        ],
      ),
    );
  }
}
