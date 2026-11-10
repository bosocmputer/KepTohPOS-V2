import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Lower half of the `/dev/components` showcase (not exported in widgets.dart).
class DevLowerSections extends StatefulWidget {
  const new({super.key});
  @override
  State<DevLowerSections> createState() => _DevLowerSectionsState();
}

class _DevLowerSectionsState extends State<DevLowerSections> {
  int _page = 1;
  String _pin = '12';
  (String, String) _tb = ('', '00000');
  String _month = '2026-11';
  static final _sampleCols = <DataTableCol<(String, String, String)>>[
    DataTableCol(key: 'no', label: 'เลขบิล', cellBuilder: (_, r) => Text(r.$1)),
    DataTableCol(key: 'tb', label: 'โต๊ะ', cellBuilder: (_, r) => Text(r.$2)),
    DataTableCol(
      key: 'total',
      label: 'ยอดรวม',
      align: ColAlign.right,
      cellBuilder: (_, r) => Text(r.$3),
    ),
  ];

  Widget _b(String l, [BtnKind k = BtnKind.normal]) =>
      Btn(label: l, kind: k, onPressed: () {});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.space4,
      children: [
        PosDataTable<(String, String, String)>(
          label: 'ตารางบิลตัวอย่าง',
          columns: _sampleCols,
          rows: const [
            ('261104-001', 'A1', '฿607'),
            ('261104-002', 'A2', '฿1,196'),
          ],
          footerCells: const [
            Text('รวมทั้งหมด'),
            SizedBox.shrink(),
            Text('฿1,803'),
          ],
        ),
        Pagination(
          page: _page,
          pages: 3,
          onChanged: (n) => setState(() => _page = n),
        ),
        PinDots(value: _pin),
        const TickerMode(
          enabled: false,
          child: PinCheckingHint(label: 'กำลังตรวจสอบ PIN...'),
        ),
        NumPad(
          value: _pin,
          maxLen: 4,
          filledKeys: true,
          showClear: true,
          onChanged: (v) => setState(() => _pin = v),
        ),
        const Empty(title: 'ยังไม่มีรายการ', text: 'กดเพิ่มรายการเพื่อเริ่ม'),
        Modal(
          title: 'ตัวอย่าง Modal',
          sub: 'คำอธิบายย่อย',
          onClose: () {},
          footer: [_b('ยกเลิก'), _b('บันทึก', BtnKind.primary)],
          child: const Text('เนื้อหาภายใน Modal'),
        ),
        Confirm(
          title: 'ยืนยันการลบ',
          text: 'คุณต้องการลบรายการนี้ใช่หรือไม่?',
          danger: true,
          onYes: () {},
          onNo: () {},
        ),
        const Center(child: AppToast(message: 'บันทึกข้อมูลเรียบร้อย')),
        FormModal(
          title: 'ตัวอย่าง FormModal',
          error: 'บันทึกไม่สำเร็จ ลองอีกครั้ง',
          onCancel: () {},
          onSubmit: () {},
          children: [
            TaxIdBranchInput(
              taxId: _tb.$1,
              branchCode: _tb.$2,
              onChanged: (t, b) => setState(() => _tb = (t, b)),
            ),
          ],
        ),
        MonthPicker(
          value: _month,
          onChanged: (v) => setState(() => _month = v),
        ),
        Wrap(
          spacing: AppDimensions.space3,
          runSpacing: AppDimensions.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const BrandLogo(),
            const BrandLogoName(),
            PendingBadge(onTap: () {}),
          ],
        ),
        const ResponsiveFormRow(
          left: Field(
            label: 'ราคาขาย',
            child: AppTextInput(value: '199', suffixText: '฿', readOnly: true),
          ),
          right: Field(
            label: 'ต้นทุน',
            child: AppTextInput(value: '120', suffixText: '฿', readOnly: true),
          ),
        ),
      ],
    );
  }
}
