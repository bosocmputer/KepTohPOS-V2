import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:flutter/material.dart';

final RegExp _rdMachineCodePattern = RegExp(r'^[A-Za-z0-9-]{1,20}$');

/// Returns a Thai error for an RD machine code the database would reject, or
/// `null` when it is acceptable. An empty code is allowed: it clears the code.
String? rdMachineCodeError(String value) {
  final v = value.trim();
  if (v.isEmpty || _rdMachineCodePattern.hasMatch(v)) return null;
  return 'ใช้ได้เฉพาะ A-Z, 0-9 และขีด (-) ไม่เกิน 20 ตัว';
}

/// Asks for the RD machine code of one device and calls [onSave] with the code
/// (`null` to clear it). Pops `true` once saved; a failure stays in the dialog.
Future<bool?> showRdMachineCodeDialog(
  BuildContext context, {
  required String deviceName,
  required String? current,
  required Future<void> Function(String? code) onSave,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _RdCodeDialog(
    deviceName: deviceName,
    current: current ?? '',
    onSave: onSave,
  ),
);

class _RdCodeDialog extends StatefulWidget {
  const new({
    required this.deviceName,
    required this.current,
    required this.onSave,
  });

  final String deviceName;
  final String current;
  final Future<void> Function(String? code) onSave;

  @override
  State<_RdCodeDialog> createState() => _RdCodeDialogState();
}

class _RdCodeDialogState extends State<_RdCodeDialog> {
  late String _value = widget.current;
  String _error = '';
  bool _busy = false;

  Future<void> _save() async {
    final invalid = rdMachineCodeError(_value);
    if (invalid != null) return setState(() => _error = invalid);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final v = _value.trim();
      await widget.onSave(v.isEmpty ? null : v);
      if (mounted) Navigator.pop(context, true);
    } on PosCommandException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormModal(
    title: 'เลขรหัสประจำเครื่อง ${widget.deviceName}',
    busy: _busy,
    error: _error,
    onSubmit: _save,
    onCancel: () => Navigator.pop(context, false),
    children: [
      Field(
        label: 'เลขรหัสประจำเครื่อง (สรรพากร)',
        hint:
            'ใส่ตามที่สรรพากรอนุมัติ (ภ.พ.06) เครื่องที่มีเลขนี้'
            ' จะพิมพ์ใบกำกับภาษีอย่างย่อได้เมื่อร้านจด VAT',
        child: AppTextInput(
          key: const ValueKey('rd-code-input'),
          value: _value,
          onChanged: (v) => setState(() {
            _value = v;
            _error = '';
          }),
        ),
      ),
    ],
  );
}
