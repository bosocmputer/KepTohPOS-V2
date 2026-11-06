import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:app/features/dashboard/presentation/widgets/dashboard_breakdown_cards.dart';
import 'package:app/features/dashboard/presentation/widgets/profit_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/dashboard/presentation/cubit/dashboard_cubit.dart';
export 'package:app/features/dashboard/presentation/widgets/dashboard_breakdown_cards.dart';
export 'package:app/features/dashboard/presentation/widgets/profit_chart.dart';

/// Builds the date-range segmented selector (`dashboard-range-seg`) for
/// `/dashboard` shown in the Topbar on tablet/desktop and inline on mobile.
Widget buildDashboardRangeSeg(DashboardCubit cubit) => Seg<String>(
  key: const ValueKey('dashboard-range-seg'),
  value: cubit.state.summary.range,
  items: const [
    SegItem(value: 'today', label: 'วันนี้'),
    SegItem(value: '7', label: '7 วัน'),
    SegItem(value: 'month', label: 'เดือนนี้'),
    SegItem(value: '30', label: '30 วัน'),
  ],
  onChanged: cubit.setRange,
);

/// Profit overview screen (`function DashboardView` in `prototype/index.html`).
class DashboardPage extends StatelessWidget {
  const new({super.key, this.onGoStockCount, this.onGoSetupCosting});

  final VoidCallback? onGoStockCount;
  final VoidCallback? onGoSetupCosting;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final cubit = context.read<DashboardCubit>();

    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        final s = state.posState;
        final sh = s.shop;
        final sum = state.summary;
        final showNet = sum.showNetProfit;
        final closed = sum.closedDays;
        final best = sum.bestDay;
        final worst = sum.worstDay;
        final bestVal = best != null ? (sum.dayMetric(best) ?? 0.0) : 0.0;
        final worstVal = worst != null ? (sum.dayMetric(worst) ?? 0.0) : 0.0;
        final firstPkg = s.packages.firstOrNull;
        final pkgSub = firstPkg != null
            ? ' · ราคา ${baht(firstPkg.adultPrice)}'
            : '';
        final netFormula = showNet
            ? ' · กำไรสุทธิ = กำไรขั้นต้น − ค่าใช้จ่ายรายวัน − '
                  'ค่าคงที่รายเดือน ÷ ${sh.openDaysPerMonth} วัน'
            : '';

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth <= AppDimensions.mobileBp;
            final pad = AppDimensions.pagePadding(constraints.maxWidth);
            return SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMobile) ...[
                    buildDashboardRangeSeg(cubit),
                    const SizedBox(height: AppDimensions.space4),
                  ],
                  DashboardHeroSection(
                    summary: sum,
                    onGoStockCount: onGoStockCount,
                    onGoSetupCosting: onGoSetupCosting,
                  ),
                  StatsGroup(
                    key: const ValueKey('dashboard-primary-stats'),
                    children: [
                      Stat(
                        label: 'ยอดขาย (ก่อน VAT)',
                        value: baht(sum.net),
                        sub: '${sum.bills} บิล',
                      ),
                      Stat(
                        label: 'ต้นทุนวัตถุดิบที่ใช้',
                        value: closed.isNotEmpty ? baht(sum.ingCost) : '–',
                        sub: 'ต้นทุนเครื่องดื่ม ${baht(sum.addonCost)}',
                      ),
                      Stat(
                        label: 'กำไรขั้นต้น',
                        value: closed.isNotEmpty ? baht(sum.profit) : '–',
                        tone: sum.profit >= 0 ? StatTone.green : StatTone.red,
                        sub: '${closed.length} วันที่ปิดยอดแล้ว',
                      ),
                      if (showNet)
                        Stat(
                          label: 'กำไรสุทธิ (ประมาณ)',
                          value: closed.isNotEmpty ? baht(sum.netProfit) : '–',
                          tone: sum.netProfit >= 0
                              ? StatTone.green
                              : StatTone.red,
                          sub: 'หักค่าใช้จ่าย ${baht(sum.spend)}',
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  StatsGroup(
                    key: const ValueKey('dashboard-secondary-stats'),
                    children: [
                      Stat(
                        label: 'ลูกค้า',
                        value: '${fmt(sum.heads)} หัว',
                        sub: sum.days.isNotEmpty
                            ? 'เฉลี่ย ${fmt(sum.avgHeadsPerDay)} หัว/วัน'
                            : '',
                      ),
                      Stat(
                        label: 'ต้นทุนวัตถุดิบต่อหัว',
                        value: sum.costPerHead != null
                            ? baht(sum.costPerHead, 2)
                            : '–',
                        sub: 'เด็กนับ ${fmtQ(sh.childHeadWeight)} หัว$pkgSub',
                      ),
                      Stat(
                        label: 'Food cost บุฟเฟต์',
                        value: sum.foodPct != null
                            ? '${fmt(sum.foodPct, 1)}%'
                            : '–',
                        tone: sum.foodPct != null && sum.foodPct! > 40
                            ? StatTone.red
                            : StatTone.neutral,
                        sub: 'ต้นทุนวัตถุดิบ ÷ ยอดขายบุฟเฟต์',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  if (sum.days.length > 1) ...[
                    Container(
                      key: const ValueKey('dashboard-profit-chart-card'),
                      padding: const EdgeInsets.all(AppDimensions.space4),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.r),
                        border: Border.all(color: t.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${sum.fieldName}รายวัน',
                                style: tt.titleLarge,
                              ),
                              Flexible(
                                child: Text(
                                  'เขียว = กำไร · แดง = ขาดทุน · '
                                  'เทา = ยังไม่ปิดยอด',
                                  style: tt.bodySmall?.copyWith(color: t.muted),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.space2),
                          ProfitChart(
                            days: sum.days,
                            showNetProfit: showNet,
                            selectedDate: state.selectedBarDate,
                            onSelectDate: cubit.selectBarDate,
                          ),
                          if (best != null && worst != null) ...[
                            const SizedBox(height: AppDimensions.space2),
                            Wrap(
                              spacing: AppDimensions.space2,
                              runSpacing: AppDimensions.space2,
                              children: [
                                Pill(
                                  tone: PillTone.green,
                                  label:
                                      'ดีที่สุด ${thDateShort(best.date)} '
                                      '${baht(bestVal)}',
                                ),
                                Pill(
                                  tone: worstVal < 0
                                      ? PillTone.red
                                      : PillTone.neutral,
                                  label:
                                      'ต่ำสุด ${thDateShort(worst.date)} '
                                      '${baht(worstVal)}',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space4),
                  ],
                  DashboardBreakdownGrid(summary: sum),
                  const SizedBox(height: AppDimensions.space4),
                  Text(
                    'กำไรขั้นต้น = ยอดขายก่อน VAT − ต้นทุนวัตถุดิบที่ใช้ − '
                    'ต้นทุนเครื่องดื่ม$netFormula'
                    ' · มูลค่าวัตถุดิบ: ${kCostMethods[sh.costMethod] ?? "-"}'
                    ' · ทุกสูตรเป็นค่าตั้งต้น รอยืนยันกับร้าน',
                    style: tt.bodySmall?.copyWith(color: t.muted),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
