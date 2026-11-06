import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/widgets/setup_nav_sidebar.dart';
import 'package:flutter/material.dart';

export 'package:app/features/setup/presentation/widgets/setup_theme_demo_panels.dart'
    show SetupDemoPanel, SetupThemeSection;

/// Editable profit & costing formulas (`CostingForm` in `prototype`).
class SetupCostingPanel extends StatefulWidget {
  const new({
    required this.shop,
    required this.totalMonthlyFixedCost,
    required this.onSave,
    this.isSaving = false,
    super.key,
  });

  final ShopConfig shop;
  final double totalMonthlyFixedCost;
  final ValueChanged<ShopConfig> onSave;
  final bool isSaving;
  @override
  State<SetupCostingPanel> createState() => _SetupCostingPanelState();
}

class _SetupCostingPanelState extends State<SetupCostingPanel> {
  late ShopConfig _v = widget.shop;
  @override
  void didUpdateWidget(covariant SetupCostingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shop != widget.shop) _v = widget.shop;
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

  Widget _dd(
    String lb,
    String h,
    String val,
    Map<String, String> map,
    ValueChanged<String> fn,
  ) => Field(
    label: lb,
    hint: h,
    child: Dropdown<String>(
      label: lb,
      value: val,
      options: [
        for (final e in map.entries)
          DropdownOption(value: e.key, label: e.value),
      ],
      onChanged: (s) => setState(() => fn(s)),
    ),
  );

  Stat _st(String l, String v, String s) => Stat(label: l, value: v, sub: s);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final calDays = DateTime(now.year, now.month + 1, 0).day;
    final isCal = _v.fixedCostDivisor == 'calendar';
    final openDays = isCal
        ? calDays
        : (_v.openDaysPerMonth <= 0 ? 30 : _v.openDaysPerMonth);
    final dailyFixed = widget.totalMonthlyFixedCost / openDays;
    final methodLabel = _v.costMethod == 'avg'
        ? 'เฉลี่ยถ่วงน้ำหนัก'
        : 'ราคาล่าสุด';
    final childMap = {
      '0.5': '0.5 หัว (ครึ่งผู้ใหญ่)',
      '1.0': '1 หัว (เท่าผู้ใหญ่)',
      '0.0': 'ไม่นับหัวเด็ก',
    };
    final dowMap = {
      for (var i = 0; i < kDowNames.length; i++) '$i': 'วัน${kDowNames[i]}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'สูตรกำไรและต้นทุน',
          desc: 'มีผลกับหน้า ภาพรวมกำไร และ รายงานรายวัน ทันทีที่บันทึก',
          actions: [
            Btn(
              key: const ValueKey('setup-save-costing-btn'),
              kind: BtnKind.primary,
              icon: 'check',
              label: widget.isSaving ? 'กำลังบันทึก...' : 'บันทึกสูตร',
              disabled: widget.isSaving,
              onPressed: () => widget.onSave(_v),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space3),
        StatsGroup(
          children: [
            _st('วิธีตีมูลค่าวัตถุดิบ', methodLabel, 'คำนวณต้นทุนรายวัน'),
            _st(
              'ค่าคงที่เฉลี่ยต่อวัน',
              baht(dailyFixed),
              isCal
                  ? '${baht(widget.totalMonthlyFixedCost)} ÷ $calDays วัน'
                        ' (ตามปฏิทิน)'
                  : '${baht(widget.totalMonthlyFixedCost)} ÷ $openDays วัน',
            ),
            _st(
              'สัดส่วนหัวเด็ก',
              '${fmtQ(_v.childHeadWeight)} หัว',
              'ผู้ใหญ่ 1 หัว · เด็กเล็กฟรี 0 หัว',
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space3),
        SetupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(
                _dd(
                  'วิธีคิดต้นทุนวัตถุดิบ',
                  'มีผลต่อรายงานต้นทุนวัตถุดิบที่ใช้จริงรายวัน',
                  _v.costMethod,
                  kCostMethods,
                  (s) => _v = _v.copyWith(costMethod: s),
                ),
                _dd(
                  'สัดส่วนหัวเด็ก (คิดต้นทุน/หัว)',
                  'น้ำหนักหัวเด็กเทียบกับผู้ใหญ่ 1 หัว',
                  _v.childHeadWeight.toString(),
                  childMap,
                  (s) => _v = _v.copyWith(
                    childHeadWeight: double.tryParse(s) ?? 0.5,
                  ),
                ),
              ),
              _row(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Field(
                      label: 'วิธีหารค่าคงที่รายเดือนเป็นรายวัน',
                      hint: 'คำนวณตามจำนวนวันจริงของเดือน (28–31) หรือกำหนดเอง',
                      child: Seg<String>(
                        key: const ValueKey('setup-fixed-divisor-seg'),
                        value: _v.fixedCostDivisor,
                        items: const [
                          SegItem(
                            value: 'calendar',
                            label: 'ตามปฏิทิน (28–31 วัน)',
                          ),
                          SegItem(value: 'custom', label: 'กำหนดเอง'),
                        ],
                        onChanged: (m) => setState(
                          () => _v = _v.copyWith(fixedCostDivisor: m),
                        ),
                      ),
                    ),
                    if (!isCal) ...[
                      const SizedBox(height: AppDimensions.space2_5),
                      Field(
                        label: 'จำนวนวันเปิดร้านต่อเดือน',
                        hint: 'ตัวหารค่าคงที่รายเดือนเป็นรายวัน',
                        child: AppTextInput(
                          value: _v.openDaysPerMonth.toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (s) {
                            final d = (int.tryParse(s) ?? 30).clamp(1, 31);
                            setState(
                              () => _v = _v.copyWith(openDaysPerMonth: d),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                _dd(
                  'วันตรวจนับวัตถุดิบประจำสัปดาห์',
                  'แจ้งเตือนตรวจนับวัตถุดิบรายสัปดาห์ในหน้าสต็อก',
                  _v.weeklyCountDow.toString(),
                  dowMap,
                  (s) => _v = _v.copyWith(weeklyCountDow: int.tryParse(s) ?? 1),
                ),
              ),
              AppSwitch(
                value: _v.showNetProfit,
                label: 'แสดงกำไรสุทธิ (หักรายจ่ายรายวัน + ค่าคงที่เฉลี่ยวัน)',
                onChanged: (on) =>
                    setState(() => _v = _v.copyWith(showNetProfit: on)),
              ),
              const SizedBox(height: AppDimensions.space3),
              Container(
                padding: const EdgeInsets.all(AppDimensions.space3),
                decoration: BoxDecoration(
                  color: t.surface2,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: t.line),
                ),
                child: Text(
                  'กำไรขั้นต้น = ขายก่อน VAT − ทุนวัตถุดิบ − ทุนเครื่องดื่ม'
                  '${_v.showNetProfit ? " · กำไรสุทธิหักค่าคงที่" : ""}',
                  style: tt.bodySmall?.copyWith(color: t.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
