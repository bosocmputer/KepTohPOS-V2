import 'dart:math' as math;

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

export 'package:app/features/sale/presentation/widgets/sale_order_panel.dart';
export 'package:app/features/sale/presentation/widgets/sale_payment_panel.dart';
export 'package:app/features/sale/presentation/widgets/sale_receipt_modal.dart';
export 'package:app/features/sale/presentation/widgets/sale_widgets.dart';

/// Modal for editing table notes (`function NoteModal` in
/// `prototype/index.html` & `design/figma/modal_edit_menu_notes.png`).
class NoteModal extends StatefulWidget {
  const new({
    required this.initialValue,
    required this.onSave,
    required this.onClose,
    super.key,
  });

  final String initialValue;
  final ValueChanged<String> onSave;
  final VoidCallback onClose;

  @override
  State<NoteModal> createState() => _NoteModalState();
}

class _NoteModalState extends State<NoteModal> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tokens.scrim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space4),
          child: Modal(
            title: 'โน้ตโต๊ะ',
            sub: 'เช่น แพ้อาหาร ขอเพิ่มน้ำจิ้ม ลูกค้าประจำ',
            onClose: widget.onClose,
            footer: [
              Btn(label: 'ยกเลิก', onPressed: widget.onClose),
              Btn(
                key: const ValueKey('note-modal-save-btn'),
                label: 'บันทึก',
                kind: BtnKind.primary,
                icon: 'check',
                onPressed: () => widget.onSave(_value.trim()),
              ),
            ],
            child: Field(
              label: 'โน้ต',
              child: AppTextInput(
                key: const ValueKey('table-note-input'),
                value: _value,
                maxLines: 3,
                placeholder: 'ระบุหมายเหตุของโต๊ะ',
                onChanged: (v) => setState(() => _value = v),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Manager-only modal for reducing/removing sent items (`function RemoveItemModal`
/// in `prototype/index.html`).
class RemoveItemModal extends StatefulWidget {
  const new({
    required this.lines,
    required this.initialSelection,
    required this.onSave,
    required this.onClose,
    super.key,
  });

  final List<SentLineItem> lines;
  final String initialSelection;
  final void Function(String kind, String key, int qty, String reason) onSave;
  final VoidCallback onClose;

  @override
  State<RemoveItemModal> createState() => _RemoveItemModalState();
}

class _RemoveItemModalState extends State<RemoveItemModal> {
  late String _selectedKey;
  int _qty = 1;
  String _reason = '';

  @override
  void initState() {
    super.initState();
    _selectedKey = widget.initialSelection;
  }

  SentLineItem? get _activeLine {
    for (final l in widget.lines) {
      if ('${l.kind}:${l.key}' == _selectedKey) return l;
    }
    return widget.lines.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final line = _activeLine;
    if (line == null) return const SizedBox.shrink();
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final clampedQty = math.min(_qty, line.qty);
    final options = widget.lines
        .map(
          (l) => DropdownOption<String>(
            value: '${l.kind}:${l.key}',
            label: '${l.name} (มี ${l.qty})',
          ),
        )
        .toList();

    return Material(
      color: t.scrim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space4),
          child: Modal(
            title: 'ลบ/ลดรายการที่ส่งแล้ว',
            sub:
                'ผู้จัดการขึ้นไปเท่านั้น · เก็บประวัติและเหตุผลไว้ · '
                'เครื่องดื่มคืนสต็อก',
            onClose: widget.onClose,
            footer: [
              Btn(label: 'ยกเลิก', onPressed: widget.onClose),
              Btn(
                key: const ValueKey('remove-item-confirm-btn'),
                label: 'ลบ $clampedQty รายการ',
                kind: BtnKind.danger,
                icon: 'trash',
                disabled: _reason.trim().isEmpty,
                onPressed: () => widget.onSave(
                  line.kind,
                  line.key,
                  clampedQty,
                  _reason.trim(),
                ),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Dropdown<String>(
                  label: 'รายการ',
                  value: '${line.kind}:${line.key}',
                  options: options,
                  onChanged: (v) => setState(() {
                    _selectedKey = v;
                    _qty = 1;
                  }),
                ),
                const SizedBox(height: AppDimensions.space4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'จำนวนที่ลบ',
                      style: tt.bodyMedium?.copyWith(
                        color: t.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    PosStepper(
                      label: 'จำนวนที่ลบ',
                      value: clampedQty,
                      min: 1,
                      onChanged: (v) => setState(
                        () => _qty = math.min(line.qty, math.max(1, v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space4),
                Field(
                  label: 'เหตุผล *',
                  child: AppTextInput(
                    key: const ValueKey('remove-item-reason-input'),
                    value: _reason,
                    placeholder: 'เช่น ลูกค้าไม่ได้สั่ง / คีย์ผิด',
                    onChanged: (v) => setState(() => _reason = v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal/confirm dialog shown when closing a table (`เก็บโต๊ะ`).
class CloseTableConfirmModal extends StatelessWidget {
  const new({
    required this.tableName,
    required this.due,
    required this.onClose,
    required this.onConfirm,
    super.key,
  });

  final String tableName;
  final int due;
  final VoidCallback onClose;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Material(
    color: context.tokens.scrim,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space4),
        child: due > 0
            ? Modal(
                title: 'ยังเก็บโต๊ะไม่ได้',
                onClose: onClose,
                footer: [
                  Btn(
                    label: 'เข้าใจแล้ว',
                    kind: BtnKind.primary,
                    onPressed: onClose,
                  ),
                ],
                child: Text(
                  'โต๊ะ $tableName ยังมียอดค้างชำระ '
                  '${baht(due, due % 100 != 0 ? 2 : 0)} '
                  'ต้องเช็กบิลให้ครบก่อนจึงเก็บโต๊ะได้',
                ),
              )
            : Confirm(
                title: 'เก็บโต๊ะ $tableName?',
                text: 'ลูกค้ากลับแล้ว โต๊ะจะกลับเป็นโต๊ะว่าง',
                yesLabel: 'เก็บโต๊ะ',
                onNo: onClose,
                onYes: onConfirm,
              ),
      ),
    ),
  );
}
