import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/widgets/receipt_card.dart';
import 'package:flutter/material.dart';

export 'package:app/features/sale/presentation/widgets/receipt_card.dart';

/// Modal dialog displayed after settling a bill or viewing a historical bill
/// (`const ReceiptModal` in `prototype/index.html`).
class ReceiptModal extends StatefulWidget {
  const new({
    required this.shop,
    required this.bill,
    required this.onDone,
    super.key,
    this.fresh = true,
    this.onPrint,
    this.staff,
    this.onVoid,
  });

  final ShopConfig shop;
  final BillRecord bill;
  final VoidCallback onDone;
  final bool fresh;
  final VoidCallback? onPrint;
  final StaffMember? staff;
  final void Function(String reason)? onVoid;

  @override
  State<ReceiptModal> createState() => _ReceiptModalState();
}

class _ReceiptModalState extends State<ReceiptModal> {
  bool _voiding = false;
  String _reason = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final bill = widget.bill;
    final changeTxt = baht(bill.change, bill.change % 1 != 0 ? 2 : 0);
    final canVoid =
        !bill.voided &&
        widget.staff != null &&
        widget.staff!.role != 'cashier' &&
        widget.onVoid != null;

    return RootOverlayBox(
      child: Material(
        key: const ValueKey('receipt-modal'),
        color: t.scrim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space4),
            child: Modal(
              title: widget.fresh ? 'รับเงินเรียบร้อย' : 'บิล ${bill.no}',
              onClose: widget.onDone,
              footer: [
                if (canVoid && !_voiding)
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
                  label: 'พิมพ์ใบเสร็จ',
                  onPressed: widget.onPrint ?? () {},
                ),
                Btn(
                  key: const ValueKey('receipt-done-btn'),
                  kind: BtnKind.primary,
                  icon: 'check',
                  label: widget.fresh ? 'เสร็จสิ้น' : 'ปิด',
                  onPressed: widget.onDone,
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.fresh) ...[
                    ResultState(
                      title: 'รับเงินเรียบร้อย',
                      text: bill.methodType == 'cash' && bill.change > 0
                          ? 'เงินทอน $changeTxt'
                          : 'ชำระผ่าน ${bill.methodName}',
                    ),
                    const SizedBox(height: AppDimensions.space3),
                  ],
                  ReceiptCard(shop: widget.shop, bill: bill),
                  if (_voiding) ...[
                    const SizedBox(height: AppDimensions.space3),
                    Container(
                      key: const ValueKey('void-confirm-box'),
                      padding: const EdgeInsets.all(AppDimensions.space3),
                      decoration: BoxDecoration(
                        color: t.dangerSoft,
                        borderRadius: BorderRadius.circular(AppDimensions.r),
                        border: Border.all(color: t.danger),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'ยกเลิกบิลนี้ — ยอดจะไม่ถูกนับในยอดขายวันนี้',
                            style: tt.bodyMedium?.copyWith(
                              color: t.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.space2),
                          Field(
                            label: 'เหตุผล',
                            child: AppTextInput(
                              key: const ValueKey('void-reason-input'),
                              value: _reason,
                              onChanged: (v) => setState(() => _reason = v),
                              placeholder: 'เช่น คีย์จำนวนคนผิด',
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
                                onPressed: () =>
                                    setState(() => _voiding = false),
                              ),
                              const SizedBox(width: AppDimensions.space2),
                              Btn(
                                key: const ValueKey('confirm-void-btn'),
                                kind: BtnKind.danger,
                                size: BtnSize.sm,
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
