import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/widgets/setup_nav_sidebar.dart';
import 'package:flutter/material.dart';

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
    final openDays = _v.openDaysPerMonth <= 0 ? 30 : _v.openDaysPerMonth;
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
              '${baht(widget.totalMonthlyFixedCost)} ÷ $openDays วัน',
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
                Field(
                  label: 'จำนวนวันเปิดร้านต่อเดือน',
                  hint: 'ตัวหารค่าคงที่รายเดือนเป็นรายวัน',
                  child: AppTextInput(
                    value: _v.openDaysPerMonth.toString(),
                    keyboardType: TextInputType.number,
                    onChanged: (s) {
                      final d = (int.tryParse(s) ?? 30).clamp(1, 31);
                      setState(() => _v = _v.copyWith(openDaysPerMonth: d));
                    },
                  ),
                ),
                _dd(
                  'วันนับของรายสัปดาห์',
                  'แจ้งเตือนนับวัตถุดิบรายสัปดาห์ในหน้าสต็อก',
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

/// Demo data management panel (`ส่งออก JSON`, `นำเข้า JSON`, `รีเซ็ตข้อมูล`).
class SetupDemoPanel extends StatelessWidget {
  const new({
    required this.posState,
    required this.onExportJson,
    required this.onImportJson,
    required this.onRequestReset,
    this.onClearDaily,
    this.onAdvanceDay,
    super.key,
  });

  final PosState posState;
  final VoidCallback onExportJson;
  final VoidCallback onImportJson;
  final VoidCallback onRequestReset;
  final VoidCallback? onClearDaily;
  final VoidCallback? onAdvanceDay;

  Widget _card(BuildContext ctx, String t, String d, List<Widget> a) {
    final tt = Theme.of(ctx).textTheme;
    return Expanded(
      child: SetupCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: tt.titleMedium),
            const SizedBox(height: 4),
            Text(d, style: tt.bodySmall?.copyWith(color: ctx.tokens.muted)),
            const SizedBox(height: AppDimensions.space3_5),
            Wrap(spacing: 8, runSpacing: 8, children: a),
          ],
        ),
      ),
    );
  }

  Stat _st(String l, String v, String s) => Stat(label: l, value: v, sub: s);
  Btn _b(String k, String ic, String lb, VoidCallback? fn, [BtnKind? kd]) =>
      Btn(
        key: ValueKey(k),
        kind: kd ?? BtnKind.normal,
        icon: ic,
        label: lb,
        onPressed: fn,
      );

  @override
  Widget build(BuildContext context) {
    final s = posState;
    const expK = 'setup-export-json-btn';
    const impK = 'setup-import-json-btn';
    const clrK = 'setup-clear-daily-btn';
    const advK = 'setup-advance-day-btn';
    const rstK = 'setup-reset-demo-btn';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'ข้อมูลตัวอย่างและสำรองข้อมูล (JSON)',
          desc: 'ส่งออกหรือนำเข้าสถานะร้านทั้งหมดเป็น JSON หรือจำลองวันขาย',
        ),
        const SizedBox(height: 12),
        StatsGroup(
          children: [
            _st('บิลขายสะสม', '${s.sales.length} บิล', 'ธุรกรรมการขายทั้งหมด'),
            _st('บิลรับของเข้า', '${s.purchases.length} ใบ', 'ประวัติรับสต็อก'),
            _st('ค่าใช้จ่าย', '${s.expenses.length} รายการ', 'จ่ายหน้าร้าน'),
            _st('กะที่ปิดแล้ว', '${s.shifts.length} กะ', 'กระทบยอดเงินสด'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card(
              context,
              'สำรอง / กู้คืนข้อมูลด้วย JSON',
              'ใช้ PosState.toJson() และ PosState.fromJson() ครบทั้งระบบ',
              [
                _b(expK, 'receipt', 'ส่งออก JSON', onExportJson),
                _b(impK, 'plus', 'นำเข้า JSON', onImportJson, BtnKind.primary),
              ],
            ),
            const SizedBox(width: 16),
            _card(
              context,
              'จำลองการขายรายวัน / รีเซ็ตข้อมูล',
              'เริ่มข้อมูลรายวันใหม่ (0 บิล) ข้ามวันจำลอง หรือรีเซ็ต 30 วัน',
              [
                if (onClearDaily != null)
                  _b(clrK, 'trash', 'เริ่มรายวันใหม่ (0 บิล)', onClearDaily),
                if (onAdvanceDay != null)
                  _b(advK, 'clock', 'ข้ามไปวันถัดไป (+1 วัน)', onAdvanceDay),
                _b(rstK, 'trash', 'รีเซ็ตตัวอย่าง 30 วัน', onRequestReset),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
