import 'package:app/core/utils/thai_tax.dart';
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
  String _branch = '00000';
  String _error = '';
  bool _busy = false;

  String? _validate() {
    if (_name.trim().isEmpty) return 'กรุณาระบุชื่อผู้ซื้อ';
    if (_address.trim().isEmpty) return 'กรุณาระบุที่อยู่ผู้ซื้อ';
    final tax = normalizeTaxId(_taxId);
    if (tax.isEmpty) return null;
    if (!isValidTaxId(tax)) return 'กรุณาตรวจเลขประจำตัวผู้เสียภาษี';
    if (!isValidBranchCode(_branch)) return 'กรุณาระบุรหัสสาขา 5 หลัก';
    return null;
  }

  Future<void> _submit() async {
    final invalid = _validate();
    if (invalid != null) return setState(() => _error = invalid);
    final tax = normalizeTaxId(_taxId);
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.onSubmit(
        _name.trim(),
        _address.trim(),
        tax.isEmpty ? null : tax,
        tax.isEmpty ? null : _branch,
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
  Widget build(BuildContext context) => FormModal(
    title: 'ออกใบกำกับเต็มรูป',
    submitLabel: 'ออกใบกำกับเต็มรูป',
    busy: _busy,
    error: _error,
    onSubmit: _submit,
    onCancel: () => Navigator.pop(context, false),
    children: [
      Field(
        label: 'ชื่อผู้ซื้อ',
        child: AppTextInput(
          key: const ValueKey('fullinv-name-input'),
          value: _name,
          onChanged: (v) => _edit(() => _name = v),
        ),
      ),
      Field(
        label: 'ที่อยู่',
        child: AppTextInput(
          key: const ValueKey('fullinv-address-input'),
          value: _address,
          maxLines: 3,
          onChanged: (v) => _edit(() => _address = v),
        ),
      ),
      TaxIdBranchInput(
        key: const ValueKey('fullinv-tax-branch'),
        taxId: _taxId,
        branchCode: _branch,
        onChanged: (t, b) => _edit(() {
          _taxId = t;
          _branch = b;
        }),
      ),
    ],
  );
}
