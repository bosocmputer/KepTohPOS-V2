import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/widgets/receipt_card.dart';
import 'package:app/features/sale/presentation/widgets/table_summary_card.dart';
import 'package:flutter/material.dart';

export 'package:app/features/sale/presentation/widgets/table_summary_card.dart';

/// Modal dialog displaying the combined table summary slip (`ใบสรุปยอดโต๊ะ`)
/// alongside tabs for each individual sub-bill in the current dining session.
class TableSummaryModal extends StatefulWidget {
  const new({
    required this.shop,
    required this.summary,
    required this.onDone,
    super.key,
    this.onPrint,
    this.staff,
    this.allowCashierVoid = false,
    this.onVoidSubBill,
  });

  final ShopConfig shop;
  final TableSummarySlip summary;
  final VoidCallback onDone;
  final VoidCallback? onPrint;
  final StaffMember? staff;
  final bool allowCashierVoid;
  final void Function(String billId, String reason)? onVoidSubBill;

  @override
  State<TableSummaryModal> createState() => _TableSummaryModalState();
}

class _TableSummaryModalState extends State<TableSummaryModal> {
  String _tab = 'summary';
  bool _voiding = false;
  String _reason = '';

  BillRecord? get _selectedBill {
    if (_tab == 'summary') return null;
    for (final b in widget.summary.bills) {
      if (b.id == _tab) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final sum = widget.summary;
    final bill = _selectedBill;
    final canVoid =
        bill != null &&
        !bill.voided &&
        !bill.isSlipPreview &&
        widget.onVoidSubBill != null &&
        (widget.allowCashierVoid ||
            (widget.staff != null && widget.staff!.role != 'cashier'));

    final voidSub = sum.voidedCount > 0 ? ' (ยกเลิก ${sum.voidedCount})' : '';

    return RootOverlayBox(
      child: Material(
        key: const ValueKey('table-summary-modal'),
        color: t.scrim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space4),
            child: Modal(
              title: 'ใบสรุปยอดโต๊ะ ${sum.tableName}',
              sub: 'รวม ${sum.bills.length} บิลย่อย$voidSub',
              onClose: widget.onDone,
              footerLeading: _voiding && bill != null
                  ? _buildVoidConfirmBox(t, tt, bill)
                  : null,
              footer: _voiding
                  ? const <Widget>[]
                  : [
                      if (canVoid)
                        Btn(
                          key: const ValueKey('receipt-void-btn'),
                          kind: BtnKind.danger,
                          icon: 'trash',
                          label: 'ยกเลิกบิลย่อยนี้',
                          onPressed: () => setState(() => _voiding = true),
                        ),
                      Btn(
                        key: const ValueKey('receipt-print-btn'),
                        icon: 'printer',
                        label: bill == null
                            ? 'พิมพ์ใบสรุปโต๊ะ'
                            : 'พิมพ์ใบเสร็จ',
                        onPressed: widget.onPrint ?? () {},
                      ),
                      Btn(
                        key: const ValueKey('receipt-done-btn'),
                        kind: BtnKind.primary,
                        icon: 'check',
                        label: 'ปิด',
                        onPressed: widget.onDone,
                      ),
                    ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Seg<String>(
                      key: const ValueKey('table-summary-tabs'),
                      value: bill != null ? bill.id : 'summary',
                      items: [
                        SegItem(
                          value: 'summary',
                          label: 'สรุปทั้งโต๊ะ (${sum.bills.length})',
                        ),
                        for (final (i, b) in sum.bills.indexed)
                          SegItem(
                            value: b.id,
                            label:
                                'บิล #${i + 1}'
                                '${b.voided ? " (ยกเลิก)" : ""}',
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _tab = v;
                        _voiding = false;
                      }),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space3),
                  if (bill == null)
                    TableSummaryCard(shop: widget.shop, summary: sum)
                  else
                    ReceiptCard(shop: widget.shop, bill: bill),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoidConfirmBox(AppTokens t, TextTheme tt, BillRecord bill) =>
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ยกเลิกบิลย่อย #${bill.no} — โต๊ะยังคงเปิดอยู่สำหรับบิลอื่น',
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
                    widget.onVoidSubBill?.call(bill.id, _reason);
                    setState(() {
                      _voiding = false;
                      _tab = 'summary';
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      );
}
