import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

/// Owner-only VAT-registered switch; guards mirror the server rule (13-digit
/// tax id to turn on; VAT mode must be 'none' to turn off).
class SetupVatRegisteredSwitch extends StatefulWidget {
  const new({required this.shop, required this.onChanged, super.key});

  final ShopConfig shop;
  final ValueChanged<ShopConfig> onChanged;

  @override
  State<SetupVatRegisteredSwitch> createState() => _State();
}

class _State extends State<SetupVatRegisteredSwitch> {
  String _error = '';

  void _toggle(bool on) {
    final taxOk = RegExp(r'^\d{13}$')
        .hasMatch(widget.shop.taxId.replaceAll(RegExp(r'[\s-]'), ''));
    final String err;
    if (on && !taxOk) {
      err = 'กรอกเลขประจำตัวผู้เสียภาษี 13 หลักก่อน';
    } else if (!on && widget.shop.vatMode != 'none') {
      err = "ตั้งโหมด VAT ของร้านเป็น 'ไม่มี VAT' ก่อน";
    } else {
      err = '';
    }
    setState(() => _error = err);
    if (err.isEmpty) widget.onChanged(widget.shop.copyWith(vatRegistered: on));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSwitch(
          key: const ValueKey('setup-vat-registered-switch'),
          value: widget.shop.vatRegistered,
          label: 'จดทะเบียนภาษีมูลค่าเพิ่ม (VAT) แล้ว',
          subtitle:
              'เปิดเมื่อร้านได้ ภ.พ.20 แล้วเท่านั้น '
              '— ใบกำกับภาษีจะออกได้หลังเปิด',
          onChanged: _toggle,
        ),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.space1),
            child: Text(
              _error,
              key: const ValueKey('setup-vat-registered-error'),
              style: TextStyle(color: t.danger, fontSize: 12),
            ),
          ),
        const SizedBox(height: AppDimensions.space3),
      ],
    );
  }
}

/// Sample bill for the live receipt preview next to the shop form.
BillRecord buildShopPreviewBill(ShopConfig shop) {
  const pkg = PackageItem(
    id: 'pk1',
    name: 'บุฟเฟต์หมูกระทะ',
    adultPrice: 19900,
    childPrice: 9900,
  );
  AddonLineInput ad(String id, String n, int p, int q) => AddonLineInput(
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
  final order = calcOrder(shop, pkg, 3, 1, 0, [
    ad('ad1', 'เบียร์สิงห์ ขวดใหญ่', 9000, 2),
    ad('ad2', 'น้ำแข็งถัง', 2000, 1),
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
    received: 100000,
    change: 100000 - order.total,
    vatMode: shop.vatMode,
    vatRate: shop.vatRate,
  );
}
