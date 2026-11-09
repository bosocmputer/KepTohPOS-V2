import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:flutter/material.dart';

/// Buyer details for a full tax invoice: (name, address, taxId?, branch?).
typedef FullInvoiceSubmit = Future<void> Function(
  String name,
  String address,
  String? taxId,
  String? branch,
);

/// Collects the buyer details and calls [onSubmit]. Pops `true` on success; a
/// failure stays in the dialog with an inline Thai message.
Future<bool?> showFullInvoiceDialog(
  BuildContext context, {
  required FullInvoiceSubmit onSubmit,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _FullInvoiceDialog(onSubmit: onSubmit),
);

class _FullInvoiceDialog extends StatefulWidget {
  const new({required this.onSubmit});

  final FullInvoiceSubmit onSubmit;

  @override
  State<_FullInvoiceDialog> createState() => _FullInvoiceDialogState();
}

class _FullInvoiceDialogState extends State<_FullInvoiceDialog> {
  String _name = '';
  String _address = '';
  String _taxId = '';
  String _branch = '';
  bool _headOffice = true;
  String _error = '';
  bool _busy = false;

  String? _validate() {
    if (_name.trim().isEmpty) return 'กรุณาระบุชื่อผู้ซื้อ';
    if (_address.trim().isEmpty) return 'กรุณาระบุที่อยู่ผู้ซื้อ';
    final tax = _taxId.trim();
    if (tax.isEmpty) return null;
    if (!RegExp(r'^\d{13}$').hasMatch(tax)) {
      return 'เลขประจำตัวผู้เสียภาษีต้องมี 13 หลัก';
    }
    if (!_headOffice && !RegExp(r'^\d{5}$').hasMatch(_branch.trim())) {
      return 'กรุณาระบุรหัสสาขา 5 หลัก';
    }
    return null;
  }

  Future<void> _submit() async {
    final invalid = _validate();
    if (invalid != null) return setState(() => _error = invalid);
    final tax = _taxId.trim();
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.onSubmit(
        _name.trim(),
        _address.trim(),
        tax.isEmpty ? null : tax,
        tax.isEmpty ? null : (_headOffice ? '00000' : _branch.trim()),
      );
      if (mounted) Navigator.pop(context, true);
    } on PosCommandException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is PosOfflineException
            ? 'ต้องออนไลน์เพื่อออกใบกำกับภาษีเต็มรูป'
            : e.message;
      });
    }
  }

  void _edit(void Function() change) => setState(() {
    change();
    _error = '';
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ออกใบกำกับเต็มรูป'),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Field(
              label: 'ชื่อผู้ซื้อ',
              child: AppTextInput(
                key: const ValueKey('fullinv-name-input'),
                value: _name,
                onChanged: (v) => _edit(() => _name = v),
              ),
            ),
            const SizedBox(height: AppDimensions.space2),
            Field(
              label: 'ที่อยู่',
              child: AppTextInput(
                key: const ValueKey('fullinv-address-input'),
                value: _address,
                maxLines: 3,
                onChanged: (v) => _edit(() => _address = v),
              ),
            ),
            const SizedBox(height: AppDimensions.space2),
            Field(
              label: 'เลขประจำตัวผู้เสียภาษี (ถ้ามี)',
              child: AppTextInput(
                key: const ValueKey('fullinv-taxid-input'),
                value: _taxId,
                keyboardType: TextInputType.number,
                onChanged: (v) => _edit(() => _taxId = v),
              ),
            ),
            if (_taxId.trim().isNotEmpty) ...[
              SwitchListTile(
                key: const ValueKey('fullinv-headoffice-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('สำนักงานใหญ่'),
                value: _headOffice,
                onChanged: (v) => _edit(() => _headOffice = v),
              ),
              if (!_headOffice)
                Field(
                  label: 'รหัสสาขา (5 หลัก)',
                  child: AppTextInput(
                    key: const ValueKey('fullinv-branch-input'),
                    value: _branch,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _edit(() => _branch = v),
                  ),
                ),
            ],
            if (_error.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.space2),
              Text(
                _error,
                key: const ValueKey('fullinv-error'),
                style: TextStyle(color: context.tokens.dangerInk),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('ยกเลิก'),
      ),
      TextButton(
        key: const ValueKey('fullinv-submit-btn'),
        onPressed: _busy ? null : _submit,
        child: const Text('ออกใบกำกับเต็มรูป'),
      ),
    ],
  );
}
