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
    const sub = 896.0;
    final svc = r2(sub * (_v.servicePct / 100));
    final vat = _v.vatMode == 'excluded'
        ? r2((sub + svc) * 0.07)
        : _v.vatMode == 'included'
        ? r2((sub + svc) * 7 / 107)
        : 0.0;
    final tot = _v.vatMode == 'excluded' ? sub + svc + vat : sub + svc;
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
      lines: const [
        OrderLineItem(
          type: 'buffet',
          name: 'บุฟเฟต์ผู้ใหญ่',
          qty: 3,
          price: 199,
        ),
        OrderLineItem(type: 'buffet', name: 'บุฟเฟต์เด็ก', qty: 1, price: 99),
        OrderLineItem(
          type: 'addon',
          name: 'เบียร์สิงห์ ขวดใหญ่',
          qty: 2,
          price: 90,
        ),
        OrderLineItem(type: 'addon', name: 'น้ำแข็งถัง', qty: 1, price: 20),
      ],
      subtotal: sub,
      service: svc,
      vat: vat,
      rounding: 0,
      total: tot,
      heads: HeadsCount(a: 3, c: 1),
      methodId: 'pm1',
      methodName: 'เงินสด',
      methodType: 'cash',
      received: 1000,
      change: 1000 - tot,
    );
  }

  Widget _row(Widget left, Widget right) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimensions.space3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppDimensions.space3_5),
        Expanded(child: right),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SetupCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _row(
                      _txt('ชื่อร้าน *', _v.name, (s) => _v.copyWith(name: s)),
                      _txt(
                        'สาขา / คำโปรย',
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
                        'เลขผู้เสียภาษี 13 หลัก',
                        _v.taxId,
                        (s) => _v.copyWith(taxId: s),
                      ),
                    ),
                    _row(
                      _txt(
                        'พร้อมเพย์ (เบอร์ / เลขบัตร)',
                        _v.promptpay,
                        (s) => _v.copyWith(promptpay: s),
                        hint: 'ใช้สร้าง QR รับชำระเงินอัตโนมัติ',
                      ),
                      _dd(
                        'ภาษีมูลค่าเพิ่ม (VAT)',
                        _v.vatMode,
                        kVatModes,
                        (s) => _v.copyWith(vatMode: s),
                      ),
                    ),
                    _row(
                      _dd(
                        'รูปแบบชำระเงินเริ่มต้น',
                        _v.payTiming,
                        kPayTimings,
                        (s) => _v.copyWith(payTiming: s),
                      ),
                      _txt(
                        'ค่าบริการ (Service %)',
                        fmtQ(_v.servicePct),
                        (s) => _v.copyWith(servicePct: double.tryParse(s) ?? 0),
                        numKey: true,
                      ),
                    ),
                    _row(
                      _dd(
                        'การปัดเศษยอดสุทธิ',
                        _v.rounding,
                        kRoundingModes,
                        (s) => _v.copyWith(rounding: s),
                      ),
                      _txt(
                        'เงินทอนตั้งต้นกะ (บาท)',
                        fmtQ(_v.defaultFloat),
                        (s) =>
                            _v.copyWith(defaultFloat: double.tryParse(s) ?? 0),
                        numKey: true,
                      ),
                    ),
                    _row(
                      _txt(
                        'ที่อยู่ร้าน (บนใบเสร็จ)',
                        _v.address,
                        (s) => _v.copyWith(address: s),
                        lines: 2,
                      ),
                      _txt(
                        'ข้อความท้ายใบเสร็จ',
                        _v.receiptFooter,
                        (s) => _v.copyWith(receiptFooter: s),
                        lines: 2,
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
              ),
            ),
            const SizedBox(width: AppDimensions.space4),
            SizedBox(
              width: 310,
              child: SetupCard(
                padding: const EdgeInsets.all(AppDimensions.space3_5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ตัวอย่างใบเสร็จ (อัปเดตสด)',
                      style: tt.labelSmall?.copyWith(color: t.muted),
                    ),
                    const SizedBox(height: AppDimensions.space2_5),
                    ReceiptCard(shop: _v, bill: _buildPreviewBill()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _txt(
    String label,
    String val,
    ShopConfig Function(String) next, {
    String? hint,
    int lines = 1,
    bool numKey = false,
  }) => Field(
    label: label,
    hint: hint,
    child: AppTextInput(
      value: val,
      maxLines: lines,
      keyboardType: numKey ? TextInputType.number : null,
      onChanged: (s) => setState(() => _v = next(s)),
    ),
  );

  Widget _dd(
    String label,
    String val,
    Map<String, String> map,
    ShopConfig Function(String) next,
  ) => Field(
    label: label,
    child: Dropdown<String>(
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
