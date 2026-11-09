import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/sale/presentation/widgets/sale_receipt_modal.dart';
import 'package:flutter/material.dart';

/// Receipt modal for a bill opened from `/bills`, with the reissue action for
/// owner/manager (see `BillsState.canReissue`).
Widget billReceiptOverlay(
  BuildContext context,
  BillsCubit cubit,
  BillRecord bill,
  StaffMember staff,
) {
  final state = cubit.state;
  return ReceiptModal(
    shop: state.posState.shop,
    bill: bill,
    fresh: false,
    staff: staff,
    onDone: () => cubit.selectBill(null),
    onVoid: (r) => cubit.voidBillById(staff: staff, reason: r),
    replacesNo: state.replacesNoOf(bill),
    extraActions: [
      if (state.canReissue(bill, staff))
        Btn(
          key: const ValueKey('receipt-reissue-btn'),
          icon: 'receipt',
          label: 'ออกใบใหม่แทน',
          onPressed: () => showReissueBillDialog(
            context,
            pos: state.posState,
            onSubmit: (r, m, a) => cubit.reissueBill(
              billId: bill.id,
              reason: r,
              methodId: m,
              bankAccountId: a,
            ),
          ),
        ),
    ],
  );
}

/// Asks for the reissue reason and optional new payment method, then calls
/// [onSubmit] (reason, methodId, bankAccountId). Pops `true` once it succeeds;
/// a failure stays in the dialog with an inline Thai message.
Future<bool?> showReissueBillDialog(
  BuildContext context, {
  required PosState pos,
  required Future<void> Function(
    String reason,
    String? methodId,
    String? bankAccountId,
  )
  onSubmit,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _ReissueDialog(pos: pos, onSubmit: onSubmit),
);

class _ReissueDialog extends StatefulWidget {
  const new({required this.pos, required this.onSubmit});

  final PosState pos;
  final Future<void> Function(String, String?, String?) onSubmit;

  @override
  State<_ReissueDialog> createState() => _ReissueDialogState();
}

class _ReissueDialogState extends State<_ReissueDialog> {
  String _reason = '';
  String? _methodId;
  String? _bankId;
  String _error = '';
  bool _busy = false;

  bool get _isTransfer =>
      widget.pos.payments.any((p) => p.id == _methodId && p.type == 'transfer');

  Future<void> _submit() async {
    if (_reason.trim().isEmpty) {
      return setState(() => _error = 'กรุณาระบุเหตุผล');
    }
    if (_isTransfer && _bankId == null) {
      return setState(() => _error = 'กรุณาเลือกบัญชีธนาคาร');
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.onSubmit(
        _reason.trim(),
        _methodId,
        _isTransfer ? _bankId : null,
      );
      if (mounted) Navigator.pop(context, true);
    } on PosCommandException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is PosOfflineException
            ? 'ต้องออนไลน์เพื่อออกใบใหม่แทน'
            : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ออกใบใหม่แทน'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(
            label: 'เหตุผล',
            child: AppTextInput(
              key: const ValueKey('reissue-reason-input'),
              value: _reason,
              onChanged: (v) => setState(() {
                _reason = v;
                _error = '';
              }),
              placeholder: 'เช่น ลูกค้าขอเปลี่ยนช่องทางชำระเงิน',
            ),
          ),
          const SizedBox(height: AppDimensions.space2),
          Field(
            label: 'ช่องทางชำระเงิน',
            child: Dropdown<String>(
              key: const ValueKey('reissue-method-dropdown'),
              value: _methodId ?? '',
              onChanged: (v) => setState(() {
                _methodId = v.isEmpty ? null : v;
                _bankId = null;
                _error = '';
              }),
              options: [
                const DropdownOption<String>(
                  value: '',
                  label: 'ใช้ช่องทางเดิม',
                ),
                for (final p in widget.pos.payments.where((p) => p.active))
                  DropdownOption<String>(value: p.id, label: p.name),
              ],
            ),
          ),
          if (_isTransfer) ...[
            const SizedBox(height: AppDimensions.space2),
            Field(
              label: 'บัญชีธนาคาร',
              child: Dropdown<String>(
                key: const ValueKey('reissue-bank-dropdown'),
                value: _bankId,
                onChanged: (v) => setState(() {
                  _bankId = v;
                  _error = '';
                }),
                options: [
                  for (final b in widget.pos.shop.bankAccounts.where(
                    (b) => b.active,
                  ))
                    DropdownOption<String>(
                      value: b.id,
                      label: '${b.bankName} ${b.accountNo}',
                    ),
                ],
              ),
            ),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space2),
            Text(
              _error,
              key: const ValueKey('reissue-error'),
              style: TextStyle(color: context.tokens.dangerInk),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('ยกเลิก'),
      ),
      TextButton(
        key: const ValueKey('reissue-submit-btn'),
        onPressed: _busy ? null : _submit,
        child: const Text('ออกใบใหม่แทน'),
      ),
    ],
  );
}
