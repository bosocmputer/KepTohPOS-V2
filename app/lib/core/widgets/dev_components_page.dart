import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/dev_components_sections.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Debug-only visual showcase (`/dev/components`) rendering every shared
/// component in Light and Dark themes.
class DevComponentsPage extends StatefulWidget {
  const new({super.key, this.forcedBrightness});
  final Brightness? forcedBrightness;
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
  AppBrandPalette _palette = AppBrandPalette.orange;
  static const _segItems = <SegItem<String>>[
    SegItem(value: 'before', label: 'จ่ายก่อนกิน', tone: SegTone.green),
    SegItem(value: 'after', label: 'กินก่อนจ่าย', tone: SegTone.orange),
  ];
  Widget _buildTopBar(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space3),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          Btn(
            key: const ValueKey('dev-components-back-btn'),
            label: 'ย้อนกลับ',
            icon: 'back',
            size: BtnSize.sm,
            onPressed: () {
              final r = GoRouter.maybeOf(context);
              (r != null && r.canPop()) ? r.pop() : r?.go('/tables');
            },
          ),
          const SizedBox(width: AppDimensions.space3),
          Text('Components (dev)', style: TextStyle(color: t.ink)),
          const Spacer(),
          Seg<AppBrandPalette>(
            value: _palette,
            items: [
              for (final p in AppBrandPalette.values)
                SegItem(value: p, label: p.label),
            ],
            onChanged: (p) => setState(() => _palette = p),
          ),
        ],
      ),
    );
  }

  Widget _themedPane(Brightness brightness, String title) => Theme(
    data: AppTheme.build(brightness: brightness, palette: _palette),
    child: Builder(builder: (ctx) => _buildThemeColumn(ctx, title)),
  );

  @override
  Widget build(BuildContext context) {
    final f = widget.forcedBrightness;
    final content = f != null
        ? SingleChildScrollView(
            child: _themedPane(
              f,
              f == Brightness.dark ? 'โหมดมืด (Dark)' : 'โหมดสว่าง (Light)',
            ),
          )
        : LayoutBuilder(
            builder: (context, c) {
              final l = _themedPane(Brightness.light, 'โหมดสว่าง (Light)');
              final d = _themedPane(Brightness.dark, 'โหมดมืด (Dark)');
              return c.maxWidth >= 960
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: SingleChildScrollView(child: l)),
                        Expanded(child: SingleChildScrollView(child: d)),
                      ],
                    )
                  : SingleChildScrollView(child: Column(children: [l, d]));
            },
          );
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(context),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _b(String l, [BtnKind k = BtnKind.normal, String? ic]) =>
      Btn(label: l, kind: k, icon: ic, onPressed: () {});

  Widget _buildThemeColumn(BuildContext context, String modeTitle) {
    final tokens = context.tokens;
    final sections = <Widget>[
      PageHeader(
        title: 'คลัง Component กลาง · $modeTitle',
        desc: 'แสดงทุก Component ตามข้อ 4 ของแผน',
        actions: const [Pill(label: 'Figma Brand', tone: PillTone.orange)],
      ),
      Toolbar(
        end: const [
          StaffShiftChip(staffName: 'คุณแอน', isShiftOpen: true),
          StaffShiftChip(staffName: 'น้องมุก', isShiftOpen: false),
        ],
        children: [
          SearchBox(
            value: _search,
            onChanged: (v) => setState(() => _search = v),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _b('Primary', BtnKind.primary, 'plus'),
          _b('Normal'),
          _b('Dark', BtnKind.dark),
          _b('Danger', BtnKind.danger),
          _b('Danger Solid', BtnKind.dangerSolid, 'trash'),
          _b('Ghost', BtnKind.ghost),
          const Btn(label: 'Disabled', disabled: true),
        ],
      ),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Pill(label: 'ว่าง'),
          Pill(label: 'มีลูกค้า', tone: PillTone.orange),
          Pill(label: 'ชำระแล้ว', tone: PillTone.green),
          Pill(label: 'เกินเวลา', tone: PillTone.red),
        ],
      ),
      Field(
        label: 'ชื่อลูกค้า / หมายเหตุ',
        hint: 'ข้อความตัวอย่างสำหรับตรวจสอบ Field',
        child: AppTextInput(
          value: _text,
          onChanged: (v) => setState(() => _text = v),
          placeholder: 'ระบุข้อความ',
        ),
      ),
      Dropdown<String>(
        label: 'เลือกโซน',
        value: _ddValue,
        options: const [
          DropdownOption(value: 'z1', label: 'โซนในร้าน', sub: '6 โต๊ะ'),
          DropdownOption(value: 'z2', label: 'โซนหน้าร้าน', sub: '4 โต๊ะ'),
        ],
        onChanged: (v) => setState(() => _ddValue = v),
      ),
      Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PosStepper(
            value: _step,
            label: 'จำนวนผู้ใหญ่',
            onChanged: (v) => setState(() => _step = v),
          ),
          Seg<String>(
            value: _seg,
            items: _segItems,
            onChanged: (v) => setState(() => _seg = v),
          ),
          AppSwitch(
            value: _seg == 'all',
            label: 'เปิดขาย',
            onChanged: (on) => setState(() => _seg = on ? 'all' : 'low'),
          ),
        ],
      ),
      Tabs<String>(
        value: _tab,
        items: const [
          TabItem(value: 'all', label: 'ทั้งหมด', count: 10, icon: 'tables'),
          TabItem(value: 'drink', label: 'เครื่องดื่ม', count: 6),
          TabItem(value: 'extra', label: 'ของทานเล่น', count: 4),
        ],
        onChanged: (v) => setState(() => _tab = v),
      ),
      const StatsGroup(
        children: [
          Stat(label: 'ยอดขายวันนี้', value: '฿28,447', sub: '32 บิล'),
          Stat(label: 'กำไรสุทธิ', value: '฿15,299', tone: StatTone.green),
          Stat(label: 'ส่วนต่าง', value: '-฿40', tone: StatTone.red),
        ],
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ProductCard(
              name: 'น้ำเปล่า 600 มล.',
              category: 'เครื่องดื่ม',
              price: 1500,
              stock: 96,
              selected: true,
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: ProductCard(
              name: 'เบียร์ช้าง ขวดใหญ่',
              category: 'แอลกอฮอล์',
              price: 8000,
              stock: 0,
            ),
          ),
        ],
      ),
      const DevLowerSections(),
    ];
    return ColoredBox(
      color: tokens.bg,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: sections,
        ),
      ),
    );
  }
}
