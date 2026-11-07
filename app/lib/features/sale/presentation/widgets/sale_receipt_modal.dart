import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/widgets/receipt_card.dart';
import 'package:app/features/sale/presentation/widgets/table_summary_modal.dart';
import 'package:flutter/material.dart';

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

  @override
  State<ReceiptModal> createState() => _ReceiptModalState();
}

class _ReceiptModalState extends State<ReceiptModal> {
  bool _voiding = false;
  String _reason = '';

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
    final changeTxt = baht(bill.change, bill.change % 100 != 0 ? 2 : 0);
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
              footerLeading: _voiding ? _buildVoidConfirmBox(t, tt) : null,
              footer: _voiding
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
                      Btn(
                        key: const ValueKey('receipt-print-btn'),
                        icon: 'printer',
                        label: bill.isSlipPreview
                            ? 'พิมพ์ใบแจ้งยอด QR'
                            : 'พิมพ์ใบเสร็จ',
                        onPressed: widget.onPrint ?? () {},
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.fresh && !bill.isSlipPreview) ...[
                    _buildFreshBanner(t, tt, bill, changeTxt),
                    const SizedBox(height: AppDimensions.space3),
                  ],
                  ReceiptCard(
                    shop: widget.shop,
                    bill: bill,
                    isCopy: widget.isCopy ?? !widget.fresh,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoidConfirmBox(AppTokens t, TextTheme tt) => Container(
    key: const ValueKey('void-confirm-box'),
    padding: const EdgeInsets.all(AppDimensions.space3),
    decoration: BoxDecoration(
      color: t.dangerSoft,
      borderRadius: BorderRadius.circular(AppDimensions.r),
      border: Border.all(color: t.danger),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ยกเลิกบิลนี้ — ยอดจะไม่ถูกนับในยอดขายวันนี้ และคืนสถานะโต๊ะ',
          style: tt.bodyMedium?.copyWith(
            color: t.danger,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppDimensions.space2),
        Wrap(
          spacing: AppDimensions.space1_5,
          runSpacing: AppDimensions.space1,
          children: [
            for (final preset in const <String>[
              'ลูกค้าเปลี่ยนใจไม่รับประทาน',
              'คีย์จำนวนคนผิด',
              'เปลี่ยนช่องทางชำระเงิน',
            ])
              Btn(
                key: ValueKey('void-preset-$preset'),
                size: BtnSize.sm,
                kind: _reason == preset ? BtnKind.primary : BtnKind.normal,
                label: preset,
                onPressed: () => setState(() => _reason = preset),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.space2),
        Field(
          label: 'เหตุผล',
          child: AppTextInput(
            key: const ValueKey('void-reason-input'),
            value: _reason,
            onChanged: (v) => setState(() => _reason = v),
            placeholder: 'เช่น ลูกค้าเปลี่ยนใจไม่รับประทาน',
          ),
        ),
        const SizedBox(height: AppDimensions.space2_5),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Btn(
              key: const ValueKey('cancel-void-btn'),
              size: BtnSize.sm,
              label: 'ไม่ยกเลิก',
              onPressed: () => setState(() => _voiding = false),
            ),
            const SizedBox(width: AppDimensions.space2),
            Btn(
              key: const ValueKey('confirm-void-btn'),
              kind: BtnKind.dangerSolid,
              size: BtnSize.sm,
              icon: 'trash',
              label: 'ยืนยันยกเลิกบิล',
              onPressed: () {
                widget.onVoid?.call(_reason);
                setState(() => _voiding = false);
              },
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildFreshBanner(
    AppTokens t,
    TextTheme tt,
    BillRecord bill,
    String changeTxt,
  ) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.space4,
      vertical: AppDimensions.space3,
    ),
    decoration: BoxDecoration(
      color: t.successSoft,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      border: Border.all(color: t.success),
    ),
    child: Row(
      children: [
        Container(
          width: AppDimensions.space9,
          height: AppDimensions.space9,
          decoration: BoxDecoration(color: t.success, shape: BoxShape.circle),
          child: Center(child: AppIcon('check', color: t.onPrimary)),
        ),
        const SizedBox(width: AppDimensions.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'รับเงินเรียบร้อย',
                style: tt.titleMedium?.copyWith(
                  color: t.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'ชำระผ่าน ${bill.methodName}',
                style: tt.labelSmall?.copyWith(color: t.ink),
              ),
            ],
          ),
        ),
        if (bill.methodType == 'cash')
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'เงินทอน',
                style: tt.labelSmall?.copyWith(
                  color: t.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                changeTxt,
                style: tt.headlineMedium?.copyWith(
                  color: t.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}
