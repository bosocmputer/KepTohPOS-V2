import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/thai_tax.dart';
import 'package:app/core/widgets/app_switch.dart';
import 'package:app/core/widgets/field.dart';
import 'package:flutter/material.dart';

/// Tax ID (13 digits) + head-office switch + 5-digit branch code, with inline
/// validation. [onChanged] gets `(taxId, branchCode)`; head office = `00000`.
class TaxIdBranchInput extends StatefulWidget {
  const new({
    required this.taxId,
    required this.branchCode,
    required this.onChanged,
    super.key,
    this.isRequired = false,
  });

  final String taxId;
  final String branchCode;
  final void Function(String taxId, String branchCode) onChanged;
  final bool isRequired;

  @override
  State<TaxIdBranchInput> createState() => _TaxIdBranchInputState();
}

class _TaxIdBranchInputState extends State<TaxIdBranchInput> {
  late bool _hq = widget.branchCode.isEmpty || widget.branchCode == '00000';

  String? get _taxError {
    final t = normalizeTaxId(widget.taxId);
    if (t.isEmpty) return null;
    return isValidTaxId(t) ? null : 'เลขประจำตัวผู้เสียภาษีต้องมี 13 หลัก';
  }

  String? get _branchError {
    final b = widget.branchCode;
    if (_hq || b.isEmpty) return null;
    return isValidBranchCode(b) ? null : 'รหัสสาขาต้องมี 5 หลัก';
  }

  Widget _err(BuildContext context, String? msg) => msg == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space1_5),
          child: Text(
            msg,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: context.tokens.danger),
          ),
        );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Field(
          label: widget.isRequired
              ? 'เลขประจำตัวผู้เสียภาษี *'
              : 'เลขประจำตัวผู้เสียภาษี',
          child: AppTextInput(
            value: widget.taxId,
            placeholder: '13 หลัก',
            keyboardType: TextInputType.number,
            onChanged: (v) => widget.onChanged(v, widget.branchCode),
          ),
        ),
        _err(context, _taxError),
        const SizedBox(height: AppDimensions.space2),
        AppSwitch(
          value: _hq,
          label: 'สำนักงานใหญ่',
          onChanged: (on) {
            setState(() => _hq = on);
            widget.onChanged(widget.taxId, on ? '00000' : '');
          },
        ),
        if (!_hq) ...[
          const SizedBox(height: AppDimensions.space2),
          Field(
            label: 'รหัสสาขา',
            child: AppTextInput(
              value: widget.branchCode,
              placeholder: '5 หลัก เช่น 00001',
              keyboardType: TextInputType.number,
              onChanged: (v) => widget.onChanged(widget.taxId, v),
            ),
          ),
          _err(context, _branchError),
        ],
      ],
    );
  }
}
