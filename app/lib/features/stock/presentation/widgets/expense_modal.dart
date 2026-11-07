import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

class _ExpenseModalRow {
  const new({required this.typeId, this.amount = '', this.note = ''});

  final String typeId;
  final String amount;
  final String note;

  _ExpenseModalRow copyWith({String? typeId, String? amount, String? note}) =>
      _ExpenseModalRow(
        typeId: typeId ?? this.typeId,
        amount: amount ?? this.amount,
        note: note ?? this.note,
      );
}

/// Modal dialog for adding or editing daily operating expenses (`ExpenseModal`
/// in `prototype/index.html:1445-1461`).
class ExpenseModal extends StatefulWidget {
  const new({
    required this.date,
    required this.expenseTypes,
    required this.initialLines,
    required this.onSave,
    required this.onClose,
    super.key,
    this.editId,
  });

  final String date;
  final List<ExpenseType> expenseTypes;
  final List<ExpenseRecord> initialLines;
  final String? editId;
  final void Function(List<ExpenseDraftLine> lines) onSave;
  final VoidCallback onClose;

  @override
  State<ExpenseModal> createState() => _ExpenseModalState();
}

class _ExpenseModalState extends State<ExpenseModal> {
  final GlobalKey _bottomKey = GlobalKey();
  late List<_ExpenseModalRow> _lines;
  String _error = '';

  void _addLine() {
    setState(() {
      _lines.add(const _ExpenseModalRow(typeId: ''));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _bottomKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 160),
          alignment: 1,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLines.isNotEmpty) {
      _lines = widget.initialLines
          .map(
            (e) => _ExpenseModalRow(
              typeId: e.typeId,
              amount: bahtInputText(e.amount),
              note: e.note,
            ),
          )
          .toList();
    } else {
      final firstType = widget.expenseTypes.isNotEmpty
          ? widget.expenseTypes.first.id
          : '';
      _lines = <_ExpenseModalRow>[_ExpenseModalRow(typeId: firstType)];
    }
  }

  void _save() {
    final valid = <ExpenseDraftLine>[];
    for (final l in _lines) {
      final amt = parseBaht(l.amount.trim());
      if (l.typeId.isNotEmpty && amt > 0) {
        valid.add(
          ExpenseDraftLine(typeId: l.typeId, amount: amt, note: l.note),
        );
      }
    }
    if (valid.isEmpty) {
      setState(() => _error = 'ใส่อย่างน้อย 1 รายการที่มียอดมากกว่า 0');
      return;
    }
    widget.onSave(valid);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final modalTotal = _lines.fold<int>(
      0,
      (sum, l) => sum + parseBaht(l.amount.trim()),
    );

    return RootOverlayBox(
      child: Material(
        key: const ValueKey('expense-modal'),
        color: t.scrim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space4),
            child: Modal(
              title: widget.editId != null
                  ? 'แก้ไขค่าใช้จ่าย'
                  : 'บันทึกค่าใช้จ่าย · ${thDateShort(widget.date)}',
              sub: 'ค่าใช้จ่ายที่ไม่เข้าสต็อก ใช้หักกำไรสุทธิ',
              onClose: widget.onClose,
              footerLeading: Wrap(
                spacing: AppDimensions.space3,
                runSpacing: AppDimensions.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'รวม ${baht(modalTotal)}',
                    style: tt.titleLarge?.copyWith(
                      color: t.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.editId == null)
                    Btn(
                      key: const ValueKey('expense-modal-add-line-btn'),
                      size: BtnSize.sm,
                      icon: 'plus',
                      label: 'เพิ่มบรรทัด',
                      onPressed: _addLine,
                    ),
                ],
              ),
              footer: [
                Btn(
                  key: const ValueKey('expense-modal-cancel-btn'),
                  label: 'ยกเลิก',
                  onPressed: widget.onClose,
                ),
                Btn(
                  key: const ValueKey('expense-modal-save-btn'),
                  kind: BtnKind.primary,
                  icon: 'check',
                  label: 'บันทึก',
                  onPressed: _save,
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _lines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppDimensions.space2_5,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Field(
                              label: i == 0 ? 'รายการ' : '',
                              child: Dropdown<String>(
                                key: ValueKey('expense-line-type-$i'),
                                value: _lines[i].typeId,
                                placeholder: 'เลือกประเภท',
                                onChanged: (v) => setState(() {
                                  _lines[i] = _lines[i].copyWith(typeId: v);
                                }),
                                options: [
                                  for (final et in widget.expenseTypes)
                                    DropdownOption<String>(
                                      value: et.id,
                                      label: et.name,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.space2),
                          Expanded(
                            flex: 2,
                            child: Field(
                              label: i == 0 ? 'ยอดเงิน (บาท)' : '',
                              child: AppTextInput(
                                key: ValueKey('expense-line-amount-$i'),
                                value: _lines[i].amount,
                                placeholder: '0',
                                suffixText: '฿',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (v) => setState(() {
                                  _lines[i] = _lines[i].copyWith(amount: v);
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.space2),
                          Expanded(
                            flex: 3,
                            child: Field(
                              label: i == 0 ? 'หมายเหตุ' : '',
                              child: AppTextInput(
                                key: ValueKey('expense-line-note-$i'),
                                value: _lines[i].note,
                                placeholder: 'เช่น ซื้อเพิ่มช่วงเย็น',
                                onChanged: (v) => setState(() {
                                  _lines[i] = _lines[i].copyWith(note: v);
                                }),
                              ),
                            ),
                          ),
                          if (widget.editId == null && _lines.length > 1) ...[
                            const SizedBox(width: AppDimensions.space1_5),
                            Field(
                              label: i == 0 ? ' ' : '',
                              child: Btn(
                                kind: BtnKind.ghost,
                                icon: 'trash',
                                semanticLabel: 'ลบบรรทัด',
                                onPressed: () =>
                                    setState(() => _lines.removeAt(i)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  SizedBox(key: _bottomKey, height: 1),
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
}
