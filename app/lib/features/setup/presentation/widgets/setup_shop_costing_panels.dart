import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/widgets/receipt_card.dart';
import 'package:app/features/setup/presentation/widgets/setup_nav_sidebar.dart';
import 'package:flutter/material.dart';

/// Editable store profile & receipt configuration (`ShopForm` + Live Preview).
class SetupShopPanel extends StatefulWidget {
  const new({
    required this.shop,
    required this.onSave,
    this.isSaving = false,
    super.key,
  });

  final ShopConfig shop;
  final ValueChanged<ShopConfig> onSave;
  final bool isSaving;

  @override
  State<SetupShopPanel> createState() => _SetupShopPanelState();
}

class _SetupShopPanelState extends State<SetupShopPanel> {
  late ShopConfig _v = widget.shop;

  @override
  void didUpdateWidget(covariant SetupShopPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shop != widget.shop) _v = widget.shop;
  }

  BillRecord _buildPreviewBill() {
    const pkg = PackageItem(
      id: 'pk1',
      name: 'บุฟเฟต์หมูกระทะ',
      adultPrice: 199,
      childPrice: 99,
    );
    AddonLineInput ad(String id, String n, double p, int q) => AddonLineInput(
      addon: AddonItem(
        id: id,
        name: n,
        category: 'เครื่องดื่ม',
        price: p,
        cost: 0,
        stock: 10,
      ),
      qty: q,
    );
    final order = calcOrder(_v, pkg, 3, 1, 0, [
      ad('ad1', 'เบียร์สิงห์ ขวดใหญ่', 90, 2),
      ad('ad2', 'น้ำแข็งถัง', 20, 1),
    ]);
    return BillRecord(
      id: 'pv',
      no: 'B261105-001',
      date: '2026-11-05',
      at: '2026-11-05T18:30:00',
      tableId: 't1',
      tableName: 'A1',
      staffId: 'st1',
      staffName: 'น้องมุก',
      packageId: 'pk1',
      lines: order.lines,
      subtotal: order.subtotal,
      service: order.service,
      vat: order.vat,
      rounding: order.rounding,
      total: order.total,
      heads: order.heads,
      methodId: 'pm1',
      methodName: 'เงินสด',
      methodType: 'cash',
      received: 1000,
      change: r2(1000 - order.total),
      vatMode: _v.vatMode,
      vatRate: _v.vatRate,
    );
  }

  Widget _row(Widget l, Widget r) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimensions.space3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: l),
        const SizedBox(width: AppDimensions.space3_5),
        Expanded(child: r),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'ข้อมูลร้านและใบเสร็จ',
          desc: 'ใช้แสดงบนใบเสร็จ คำนวณภาษี/ค่าบริการ และสร้าง QR พร้อมเพย์',
          actions: [
            Btn(
              key: const ValueKey('setup-save-shop-btn'),
              kind: BtnKind.primary,
              icon: 'check',
              label: widget.isSaving ? 'กำลังบันทึก...' : 'บันทึกการตั้งค่า',
              disabled: widget.isSaving || _v.name.trim().isEmpty,
              onPressed: () => widget.onSave(_v),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space3),
        LayoutBuilder(
          builder: (context, c) {
            final formCard = SetupCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row(
                    _txt('ชื่อร้าน *', _v.name, (s) => _v.copyWith(name: s)),
                    _txt(
                      'ชื่อสาขา / คำอธิบายร้าน',
                      _v.branch,
                      (s) => _v.copyWith(branch: s),
                    ),
                  ),
                  _row(
                    _txt(
                      'เบอร์โทรศัพท์',
                      _v.phone,
                      (s) => _v.copyWith(phone: s),
                    ),
                    _txt(
                      'เลขประจำตัวผู้เสียภาษี (13 หลัก)',
                      _v.taxId,
                      (s) => _v.copyWith(taxId: s),
                    ),
                  ),
                  _row(
                    _txt(
                      'หมายเลขพร้อมเพย์ (เบอร์โทรศัพท์ / เลขประจำตัว)',
                      _v.promptpay,
                      (s) => _v.copyWith(promptpay: s),
                      hint: 'ใช้สร้าง QR รับชำระเงินอัตโนมัติบนใบเสร็จ',
                    ),
                    _dd(
                      'ประเภทภาษีมูลค่าเพิ่ม (VAT)',
                      _v.vatMode,
                      kVatModes,
                      (s) => _v.copyWith(vatMode: s),
                    ),
                  ),
                  _row(
                    _txt(
                      'อัตราภาษีมูลค่าเพิ่ม (%)',
                      fmtQ(_v.vatRate),
                      (s) => _v.copyWith(vatRate: double.tryParse(s) ?? 0),
                      hint: 'ค่าเริ่มต้น 7%',
                      numKey: true,
                      inputKey: const ValueKey('setup-vat-rate-input'),
                    ),
                    _txt(
                      'อัตราค่าบริการ (%)',
                      fmtQ(_v.servicePct),
                      (s) => _v.copyWith(servicePct: double.tryParse(s) ?? 0),
                      numKey: true,
                    ),
                  ),
                  _row(
                    _dd(
                      'รูปแบบชำระเงินเริ่มต้น',
                      _v.payTiming,
                      kPayTimings,
                      (s) => _v.copyWith(payTiming: s),
                    ),
                    _dd(
                      'การปัดเศษยอดสุทธิ',
                      _v.rounding,
                      kRoundingModes,
                      (s) => _v.copyWith(rounding: s),
                    ),
                  ),
                  _row(
                    _txt(
                      'เงินทอนตั้งต้นกะ (บาท)',
                      fmtQ(_v.defaultFloat),
                      (s) => _v.copyWith(defaultFloat: double.tryParse(s) ?? 0),
                      numKey: true,
                    ),
                    _txt(
                      'ที่อยู่ร้าน (บนใบเสร็จ)',
                      _v.address,
                      (s) => _v.copyWith(address: s),
                    ),
                  ),
                  _row(
                    _txt(
                      'ข้อความท้ายใบเสร็จ',
                      _v.receiptFooter,
                      (s) => _v.copyWith(receiptFooter: s),
                    ),
                    _dd(
                      'เวลาตัดรอบวันขาย',
                      _v.dayCutoffMinutes.toString(),
                      kDayCutoffs,
                      (s) =>
                          _v.copyWith(dayCutoffMinutes: int.tryParse(s) ?? 0),
                      hint: 'บิลก่อนเวลานี้นับเป็นยอดขายของวันก่อนหน้า',
                      ddKey: const ValueKey('setup-day-cutoff-dropdown'),
                    ),
                  ),
                  AppSwitch(
                    value: _v.useTimer,
                    label: 'แสดงตัวจับเวลาโต๊ะ (นาทีที่นั่งทาน / เตือน)',
                    onChanged: (on) =>
                        setState(() => _v = _v.copyWith(useTimer: on)),
                  ),
                ],
              ),
            );
            final receiptCard = SetupCard(
              padding: const EdgeInsets.all(AppDimensions.space3_5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ตัวอย่างใบเสร็จรับเงิน',
                    style: tt.labelSmall?.copyWith(color: t.muted),
                  ),
                  const SizedBox(height: AppDimensions.space2_5),
                  ReceiptCard(shop: _v, bill: _buildPreviewBill()),
                ],
              ),
            );
            if (c.maxWidth < AppDimensions.mobileBp) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [formCard, const SizedBox(height: 16), receiptCard],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: formCard),
                const SizedBox(width: AppDimensions.space4),
                SizedBox(width: 310, child: receiptCard),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _txt(
    String label,
    String val,
    ShopConfig Function(String) next, {
    String? hint,
    bool numKey = false,
    Key? inputKey,
  }) => Field(
    label: label,
    hint: hint,
    child: AppTextInput(
      key: inputKey,
      value: val,
      keyboardType: numKey ? TextInputType.number : null,
      onChanged: (s) => setState(() => _v = next(s)),
    ),
  );

  Widget _dd(
    String label,
    String val,
    Map<String, String> map,
    ShopConfig Function(String) next, {
    String? hint,
    Key? ddKey,
  }) => Field(
    label: label,
    hint: hint,
    child: Dropdown<String>(
      key: ddKey,
      label: label,
      value: val,
      options: [
        for (final e in map.entries)
          DropdownOption(value: e.key, label: e.value),
      ],
      onChanged: (s) => setState(() => _v = next(s)),
    ),
  );
}
