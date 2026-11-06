import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/widgets/setup_nav_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Widget _twoColCards(Widget left, Widget right) => LayoutBuilder(
  builder: (_, c) => c.maxWidth < AppDimensions.mobileBp
      ? Column(children: [left, const SizedBox(height: 16), right])
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        ),
);

/// Theme mode (`light`/`dark`/`system`) and brand palette selector section.
class SetupThemeSection extends StatelessWidget {
  const new({super.key});

  Widget _paletteBtn(
    BuildContext ctx,
    AppBrandPalette p,
    AppBrandPalette active,
    ThemeCubit? cubit,
  ) {
    final t = ctx.tokens;
    final sel = p == active;
    return Material(
      color: sel ? t.primarySoft : t.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: sel ? t.primary : t.line, width: sel ? 1.5 : 1),
      ),
      child: InkWell(
        key: ValueKey('palette-${p.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => cubit?.setPalette(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: p.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                p.label,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: sel ? t.primaryInk : t.ink,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final cubit = context.watch<ThemeCubit?>();
    final state = cubit?.state ?? const ThemeState();
    final subStyle = tt.bodySmall?.copyWith(color: t.muted);

    final modeCard = SetupCard(
      key: const ValueKey('setup-theme-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('โหมดสีหน้าจอ', style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(
            'โหมดสว่างเหมาะกับหน้าร้านที่มีแสงสว่างมาก '
            'ส่วนโหมดมืดช่วยถนอมสายตาในช่วงค่ำ',
            style: subStyle,
          ),
          const SizedBox(height: 12),
          Seg<AppThemeMode>(
            label: 'โหมดสี',
            value: state.mode,
            items: const [
              SegItem(value: AppThemeMode.light, label: 'สว่าง'),
              SegItem(value: AppThemeMode.dark, label: 'มืด'),
              SegItem(value: AppThemeMode.system, label: 'ตามเครื่อง'),
            ],
            onChanged: (m) => cubit?.setMode(m),
          ),
          const SizedBox(height: 16),
          Text('โทนสีหลักของระบบ', style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(
            'ปรับเปลี่ยนสีปุ่มหลัก แถบเมนู และป้ายสถานะทั่วทั้งระบบ',
            style: subStyle,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in AppBrandPalette.values)
                _paletteBtn(context, p, state.palette, cubit),
            ],
          ),
        ],
      ),
    );

    final previewCard = SetupCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ตัวอย่างโหมดปัจจุบัน', style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(
            'โทนสีที่เลือก: ${state.palette.label} · โหมด${state.mode.label}',
            style: subStyle,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('โต๊ะ A1 · กำลังทาน', style: tt.labelSmall),
                        Text('บุฟเฟต์ ฿199', style: tt.titleMedium),
                      ],
                    ),
                    const Pill(tone: PillTone.green, label: 'อ่านง่าย ชัดเจน'),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Btn(
                      kind: BtnKind.primary,
                      size: BtnSize.sm,
                      icon: 'check',
                      label: 'ปุ่มหลัก (${state.palette.label})',
                      onPressed: () {},
                    ),
                    const Pill(tone: PillTone.orange, label: 'ป้ายสถานะสีหลัก'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        const PageHeader(
          title: 'ธีมและการแสดงผล',
          desc: 'กำหนดโหมดสว่าง/มืด และเลือกโทนสีหลักของระบบตามเอกลักษณ์ร้าน',
        ),
        _twoColCards(modeCard, previewCard),
      ],
    );
  }
}

/// Data backup & simulation panel (`SetupDemoPanel`).
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
    return SetupCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(d, style: tt.bodySmall?.copyWith(color: ctx.tokens.muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: a),
        ],
      ),
    );
  }

  Stat _st(String l, String v, String s) => Stat(label: l, value: v, sub: s);
  Btn _b(String k, String ic, String lb, VoidCallback? fn, [BtnKind? kd]) =>
      Btn(
        key: ValueKey('setup-$k-btn'),
        kind: kd ?? BtnKind.normal,
        icon: ic,
        label: lb,
        onPressed: fn,
      );

  @override
  Widget build(BuildContext context) {
    final s = posState;
    final backupCard = _card(
      context,
      'สำรองและกู้คืนข้อมูลระบบ',
      'ส่งออกข้อมูลการตั้งค่าและประวัติรายการทั้งหมดเพื่อสำรองหรือกู้คืน',
      [
        _b('export-json', 'receipt', 'ส่งออก JSON', onExportJson),
        _b('import-json', 'plus', 'นำเข้า JSON', onImportJson, BtnKind.primary),
      ],
    );
    final simCard = _card(
      context,
      'เครื่องมือจำลองการขายและรีเซ็ตข้อมูล (สำหรับทดสอบ)',
      'เริ่มข้อมูลรายวันใหม่ (0 บิล) ข้ามวันจำลอง หรือรีเซ็ตตัวอย่าง 30 วัน',
      [
        if (onClearDaily != null)
          _b('clear-daily', 'trash', 'เริ่มรายวันใหม่ (0 บิล)', onClearDaily),
        if (onAdvanceDay != null)
          _b('advance-day', 'clock', 'ข้ามไปวันถัดไป (+1 วัน)', onAdvanceDay),
        _b('reset-demo', 'trash', 'รีเซ็ตตัวอย่าง 30 วัน', onRequestReset),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        const PageHeader(
          title: 'การสำรองข้อมูลและจำลองข้อมูลระบบ',
          desc: 'สำรองหรือกู้คืนสถานะร้านทั้งหมด หรือใช้เครื่องมือจำลองวันขาย',
        ),
        StatsGroup(
          children: [
            _st('บิลขายสะสม', '${s.sales.length} บิล', 'ธุรกรรมการขายทั้งหมด'),
            _st('บิลรับของเข้า', '${s.purchases.length} ใบ', 'ประวัติรับสต็อก'),
            _st('ค่าใช้จ่าย', '${s.expenses.length} รายการ', 'จ่ายหน้าร้าน'),
            _st('กะที่ปิดแล้ว', '${s.shifts.length} กะ', 'กระทบยอดเงินสด'),
          ],
        ),
        _twoColCards(backupCard, simCard),
      ],
    );
  }
}
