import 'dart:async';

import 'package:app/core/printer/printer_hub_modal.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/widgets/receipt_card.dart';
import 'package:app/features/sale/presentation/widgets/table_summary_modal.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

export 'package:app/features/sale/presentation/widgets/receipt_card.dart';
export 'package:app/features/sale/presentation/widgets/table_summary_modal.dart';

/// Modal dialog displayed after settling a bill, previewing an open table's
/// POS slip, or viewing a historical bill (`const ReceiptModal`).
class ReceiptModal extends StatefulWidget {
  const new({
    required this.shop,
    required this.bill,
    required this.onDone,
    super.key,
    this.fresh = true,
    this.isCopy,
    this.doneLabel,
    this.onPrint,
    this.staff,
    this.onVoid,
    this.onVoidSubBill,
    this.tableSummary,
    this.allowCashierVoid = false,
    this.onCancelTable,
    this.extraActions = const <Widget>[],
    this.replacesNo,
  });

  final ShopConfig shop;
  final BillRecord bill;
  final VoidCallback onDone;
  final bool fresh;
  final bool? isCopy;
  final String? doneLabel;
  final VoidCallback? onPrint;
  final StaffMember? staff;
  final void Function(String reason)? onVoid;
  final void Function(String billId, String reason)? onVoidSubBill;
  final TableSummarySlip? tableSummary;
  final bool allowCashierVoid;
  final VoidCallback? onCancelTable;
  final List<Widget> extraActions;
  final String? replacesNo;

  @override
  State<ReceiptModal> createState() => _ReceiptModalState();
}

class _ReceiptModalState extends State<ReceiptModal>
    with SingleTickerProviderStateMixin {
  bool _voiding = false;
  String _reason = '';
  late bool _showConfetti = widget.fresh && !widget.bill.isSlipPreview;
  Timer? _confettiTimer;
  AnimationController? _confettiCtrl;

  @override
  void initState() {
    super.initState();
    if (_showConfetti) {
      _confettiCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1350),
      )..forward();
      _confettiTimer = Timer(const Duration(milliseconds: 1350), _skipConfetti);
    }
    final hub = PrinterHub.instance;
    if (widget.fresh &&
        !widget.bill.isSlipPreview &&
        hub.settings.autoPrintOnSettle &&
        hub.isReadyToPrint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          hub.printBill(
            widget.shop,
            widget.bill,
            replacesNo: widget.replacesNo,
          ),
        );
      });
    }
  }

  void _skipConfetti() {
    _confettiTimer?.cancel();
    _confettiCtrl?.stop();
    if (mounted && _showConfetti) setState(() => _showConfetti = false);
  }

  @override
  void dispose() {
    _confettiTimer?.cancel();
    _confettiCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sum = widget.tableSummary;
    if (!widget.fresh && sum != null && sum.bills.length >= 2) {
      return TableSummaryModal(
        shop: widget.shop,
        summary: sum,
        onDone: widget.onDone,
        onPrint: widget.onPrint,
        staff: widget.staff,
        allowCashierVoid: widget.allowCashierVoid,
        onVoidSubBill: widget.onVoidSubBill,
      );
    }
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final bill = widget.bill;
    final canVoid =
        !bill.voided &&
        !bill.isSlipPreview &&
        widget.onVoid != null &&
        (widget.allowCashierVoid ||
            (widget.staff != null && widget.staff!.role != 'cashier'));
    final canCancelTable = bill.isSlipPreview && widget.onCancelTable != null;
    final title = bill.isSlipPreview
        ? 'ใบแจ้งยอด POS · โต๊ะ ${bill.tableName}'
        : (widget.fresh ? 'รับเงินเรียบร้อย' : 'บิล ${bill.no}');

    return RootOverlayBox(
      child: Material(
        key: const ValueKey('receipt-modal'),
        color: t.scrim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space4),
            child: Modal(
              title: title,
              onClose: widget.onDone,
              footerLeading: !_showConfetti && _voiding
                  ? _buildVoidConfirmBox(t, tt)
                  : null,
              footer: _showConfetti || _voiding
                  ? const <Widget>[]
                  : [
                      if (canCancelTable)
                        Btn(
                          key: const ValueKey('receipt-cancel-table-btn'),
                          kind: BtnKind.danger,
                          icon: 'trash',
                          label: 'ยกเลิกโต๊ะ (ลูกค้าเปลี่ยนใจ)',
                          onPressed: widget.onCancelTable,
                        ),
                      if (canVoid)
                        Btn(
                          key: const ValueKey('receipt-void-btn'),
                          kind: BtnKind.danger,
                          icon: 'trash',
                          label: 'ยกเลิกบิล',
                          onPressed: () => setState(() => _voiding = true),
                        ),
                      ...widget.extraActions,
                      Btn(
                        key: const ValueKey('receipt-print-btn'),
                        icon: 'printer',
                        label: bill.isSlipPreview
                            ? 'พิมพ์ใบแจ้งยอด QR'
                            : 'พิมพ์ใบเสร็จ',
                        onPressed:
                            widget.onPrint ??
                            () => printBillWithHub(
                              context,
                              shop: widget.shop,
                              bill: bill,
                              isCopy: widget.isCopy ?? !widget.fresh,
                              replacesNo: widget.replacesNo,
                            ),
                      ),
                      Btn(
                        key: const ValueKey('receipt-done-btn'),
                        kind: BtnKind.primary,
                        icon: 'check',
                        label:
                            widget.doneLabel ??
                            (widget.fresh && !bill.isSlipPreview
                                ? 'เสร็จสิ้น'
                                : 'ปิด'),
                        onPressed: widget.onDone,
                      ),
                    ],
              child: _showConfetti
                  ? _buildConfettiView(t, tt, bill)
                  : ReceiptCard(
                      shop: widget.shop,
                      bill: bill,
                      isCopy: widget.isCopy ?? !widget.fresh,
                      replacesNo: widget.replacesNo,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfettiView(AppTokens t, TextTheme tt, BillRecord bill) {
    final methodLabel = bill.methodName.isNotEmpty
        ? bill.methodName
        : (bill.methodType == 'qr' ? 'พร้อมเพย์ QR' : 'เงินสด');
    return GestureDetector(
      key: const ValueKey('payment-success-confetti'),
      behavior: HitTestBehavior.opaque,
      onTap: _skipConfetti,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/success_confetti.json',
              controller: _confettiCtrl,
              width: 250,
              height: 250,
              repeat: false,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.check_circle_rounded, size: 96, color: t.success),
            ),
            const SizedBox(height: AppDimensions.space2),
            Text(
              'รับเงินเรียบร้อย',
              style: tt.headlineSmall?.copyWith(
                color: t.success,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppDimensions.space1),
            Text(
              'ชำระผ่าน $methodLabel · ${bahtSmart(bill.total)}',
              style: tt.bodyMedium?.copyWith(color: t.ink),
            ),
            if (bill.methodType == 'cash' && bill.change > 0) ...[
              const SizedBox(height: AppDimensions.space3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space4,
                  vertical: AppDimensions.space2,
                ),
                decoration: BoxDecoration(
                  color: t.successSoft,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  border: Border.all(color: t.success),
                ),
                child: Text(
                  'เงินทอน ${bahtSmart(bill.change)}',
                  style: tt.titleMedium?.copyWith(
                    color: t.success,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.space4),
            Text(
              'แตะเพื่อดูใบเสร็จทันที',
              style: tt.bodySmall?.copyWith(color: t.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoidConfirmBox(AppTokens t, TextTheme tt) =>
      VoidReasonConfirmBox(
        title: 'ยกเลิกบิลนี้ — ยอดจะไม่ถูกนับในยอดขายวันนี้ และคืนสถานะโต๊ะ',
        reason: _reason,
        onReasonChanged: (v) => setState(() => _reason = v),
        onCancel: () => setState(() => _voiding = false),
        onConfirm: () {
          widget.onVoid?.call(_reason);
          setState(() => _voiding = false);
        },
      );
}
