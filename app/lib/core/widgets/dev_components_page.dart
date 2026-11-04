import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Debug-only visual showcase (`/dev/components`) rendering every shared
/// component in both Light and Dark themes side-by-side.
class DevComponentsPage extends StatefulWidget {
  const new({super.key});

  @override
  State<DevComponentsPage> createState() => _DevComponentsPageState();
}

class _DevComponentsPageState extends State<DevComponentsPage> {
  String _search = '';
  String _text = 'โต๊ะ A1';
  String _ddValue = 'z1';
  int _step = 2;
  String _seg = 'before';
  String _tab = 'all';
  String _pin = '12';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final lightTheme = AppTheme.build(brightness: Brightness.light);
    final darkTheme = AppTheme.build(brightness: Brightness.dark);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final lightPane = Theme(
            data: lightTheme,
            child: Builder(
              builder: (ctx) => _buildThemeColumn(ctx, 'โหมดสว่าง (Light)'),
            ),
          );
          final darkPane = Theme(
            data: darkTheme,
            child: Builder(
              builder: (ctx) => _buildThemeColumn(ctx, 'โหมดมืด (Dark)'),
            ),
          );
          if (constraints.maxWidth >= 960) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SingleChildScrollView(child: lightPane)),
                Expanded(child: SingleChildScrollView(child: darkPane)),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(children: [lightPane, darkPane]),
          );
        },
      ),
    );
  }

  Widget _buildThemeColumn(BuildContext context, String modeTitle) {
    final tokens = context.tokens;
    const gap = SizedBox(height: AppDimensions.space4);
    return ColoredBox(
      color: tokens.bg,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'คลัง Component กลาง · $modeTitle',
              desc: 'แสดงทุก Component ตามข้อ 4 ของแผน',
              actions: const [
                Pill(label: 'Figma Brand', tone: PillTone.orange),
              ],
            ),
            gap,
            Toolbar(
              end: const [Avatar(name: 'คุณต้อม')],
              children: [
                SearchBox(
                  value: _search,
                  onChanged: (v) => setState(() => _search = v),
                ),
              ],
            ),
            gap,
            Wrap(
              spacing: AppDimensions.space2,
              runSpacing: AppDimensions.space2,
              children: [
                Btn(
                  label: 'Primary',
                  kind: BtnKind.primary,
                  icon: 'plus',
                  onPressed: () {},
                ),
                Btn(label: 'Normal', onPressed: () {}),
                Btn(label: 'Dark', kind: BtnKind.dark, onPressed: () {}),
                Btn(label: 'Danger', kind: BtnKind.danger, onPressed: () {}),
                Btn(
                  label: 'Danger Solid',
                  kind: BtnKind.dangerSolid,
                  icon: 'trash',
                  onPressed: () {},
                ),
                Btn(label: 'Ghost', kind: BtnKind.ghost, onPressed: () {}),
                const Btn(label: 'Disabled', disabled: true),
              ],
            ),
            gap,
            const Wrap(
              spacing: AppDimensions.space2,
              runSpacing: AppDimensions.space2,
              children: [
                Pill(label: 'ว่าง', showDot: true),
                Pill(label: 'มีลูกค้า', tone: PillTone.orange, showDot: true),
                Pill(label: 'ชำระแล้ว', tone: PillTone.green, showDot: true),
                Pill(label: 'เกินเวลา', tone: PillTone.red, showDot: true),
              ],
            ),
            gap,
            Field(
              label: 'ชื่อลูกค้า / หมายเหตุ',
              hint: 'ข้อความตัวอย่างสำหรับตรวจสอบ Field',
              child: AppTextInput(
                value: _text,
                onChanged: (v) => setState(() => _text = v),
                placeholder: 'ระบุข้อความ',
              ),
            ),
            gap,
            Dropdown<String>(
              label: 'เลือกโซน',
              value: _ddValue,
              options: const [
                DropdownOption(value: 'z1', label: 'โซนในร้าน', sub: '6 โต๊ะ'),
                DropdownOption(
                  value: 'z2',
                  label: 'โซนหน้าร้าน',
                  sub: '4 โต๊ะ',
                ),
              ],
              onChanged: (v) => setState(() => _ddValue = v),
            ),
            gap,
            Row(
              children: [
                PosStepper(
                  value: _step,
                  label: 'จำนวนผู้ใหญ่',
                  onChanged: (v) => setState(() => _step = v),
                ),
                const SizedBox(width: AppDimensions.space4),
                Flexible(
                  child: Seg<String>(
                    value: _seg,
                    items: const [
                      SegItem(value: 'before', label: 'จ่ายก่อนกิน'),
                      SegItem(value: 'after', label: 'กินก่อนจ่าย'),
                    ],
                    onChanged: (v) => setState(() => _seg = v),
                  ),
                ),
              ],
            ),
            gap,
            Tabs<String>(
              value: _tab,
              items: const [
                TabItem(
                  value: 'all',
                  label: 'ทั้งหมด',
                  count: 10,
                  icon: 'tables',
                ),
                TabItem(value: 'drink', label: 'เครื่องดื่ม', count: 6),
                TabItem(value: 'extra', label: 'ของทานเล่น', count: 4),
              ],
              onChanged: (v) => setState(() => _tab = v),
            ),
            gap,
            const StatsGroup(
              children: [
                Stat(label: 'ยอดขายวันนี้', value: '฿28,447', sub: '32 บิล'),
                Stat(
                  label: 'กำไรสุทธิ',
                  value: '฿15,299',
                  tone: StatTone.green,
                ),
                Stat(label: 'ส่วนต่าง', value: '-฿40', tone: StatTone.red),
              ],
            ),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ProductCard(
                    name: 'น้ำเปล่า 600 มล.',
                    category: 'เครื่องดื่ม',
                    price: 15,
                    stock: 96,
                    selected: true,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: AppDimensions.space3),
                const Expanded(
                  child: ProductCard(
                    name: 'เบียร์ช้าง ขวดใหญ่',
                    category: 'แอลกอฮอล์',
                    price: 80,
                    stock: 0,
                  ),
                ),
              ],
            ),
            gap,
            PosDataTable<(String, String, String)>(
              label: 'ตารางบิลตัวอย่าง',
              columns: [
                DataTableCol(
                  key: 'no',
                  label: 'เลขบิล',
                  cellBuilder: (_, r) => Text(r.$1),
                ),
                DataTableCol(
                  key: 'table',
                  label: 'โต๊ะ',
                  cellBuilder: (_, r) => Text(r.$2),
                ),
                DataTableCol(
                  key: 'total',
                  label: 'ยอดรวม',
                  align: ColAlign.right,
                  cellBuilder: (_, r) => Text(r.$3),
                ),
              ],
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
            const SizedBox(height: AppDimensions.space3),
            Pagination(
              page: _page,
              pages: 3,
              onChanged: (n) => setState(() => _page = n),
            ),
            gap,
            PinDots(value: _pin),
            NumPad(
              value: _pin,
              maxLen: 4,
              onChanged: (v) => setState(() => _pin = v),
            ),
            gap,
            const Empty(
              title: 'ยังไม่มีรายการ',
              text: 'กดเพิ่มรายการเพื่อเริ่ม',
            ),
            gap,
            Modal(
              title: 'ตัวอย่าง Modal',
              sub: 'คำอธิบายย่อย',
              onClose: () {},
              footer: [
                Btn(label: 'ยกเลิก', onPressed: () {}),
                Btn(label: 'บันทึก', kind: BtnKind.primary, onPressed: () {}),
              ],
              child: const Text('เนื้อหาภายใน Modal'),
            ),
            gap,
            Confirm(
              title: 'ยืนยันการลบ',
              text: 'คุณต้องการลบรายการนี้ใช่หรือไม่?',
              danger: true,
              onYes: () {},
              onNo: () {},
            ),
            gap,
            const Center(child: AppToast(message: 'บันทึกข้อมูลเรียบร้อย')),
          ],
        ),
      ),
    );
  }
}
