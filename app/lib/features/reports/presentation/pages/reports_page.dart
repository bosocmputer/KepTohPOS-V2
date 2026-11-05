import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:app/features/reports/presentation/widgets/daily_report_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/reports/presentation/cubit/reports_cubit.dart';
export 'package:app/features/reports/presentation/widgets/daily_report_table.dart';

/// Badge indicating formulas use provisional defaults (`PendingBadge` in
/// `prototype/index.html:1528`).
class PendingBadge extends StatelessWidget {
  const new({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const pill = Pill(
      key: ValueKey('pending-badge'),
      tone: PillTone.orange,
      label: 'ค่าตั้งต้น · รอยืนยันกับร้าน',
    );
    return onTap == null
        ? pill
        : InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            onTap: onTap,
            child: pill,
          );
  }
}

/// Column definition for [DailyReportTable].
class ReportColSpec {
  const new(this.label, this.width, this.cell, this.foot);
  final String label;
  final double width;
  final Widget Function(LedgerDaySummary d) cell;
  final String foot;
}

Widget _profitText(AppTokens t, double? v) => v == null
    ? const Text('–')
    : Text(
        fmt(v),
        style: TextStyle(
          color: v >= 0 ? t.successInk : t.dangerInk,
          fontWeight: FontWeight.w700,
        ),
      );

/// Builds the metric columns for [DailyReportTable].
List<ReportColSpec> buildReportColumns(
  MonthlyReportSummary report,
  AppTokens t,
) => <ReportColSpec>[
  ReportColSpec('บิล', 56, (d) => Text('${d.bills}'), '${report.totalBills}'),
  ReportColSpec('หัว', 60, (d) => Text('${d.heads}'), '${report.totalHeads}'),
  ReportColSpec(
    'บุฟเฟต์',
    88,
    (d) => Text(fmt(d.buffetNet)),
    fmt(report.totalBuffetNet),
  ),
  ReportColSpec(
    'ขายเสริม',
    86,
    (d) => Text(fmt(d.addonNet)),
    fmt(report.totalAddonNet),
  ),
  ReportColSpec('รวมขาย', 92, (d) => Text(fmt(d.net)), fmt(report.totalNet)),
  ReportColSpec(
    'ซื้อเข้า',
    88,
    (d) => Text(fmt(d.purchases)),
    fmt(report.totalPurchases),
  ),
  ReportColSpec(
    'ต้นทุนวัตถุดิบ',
    106,
    (d) => Text(fmt(d.ingCost)),
    fmt(report.closedIngCost),
  ),
  ReportColSpec(
    'ต้นทุนเครื่องดื่ม',
    114,
    (d) => Text(fmt(d.addonCost)),
    fmt(report.closedAddonCost),
  ),
  ReportColSpec(
    'กำไรขั้นต้น',
    100,
    (d) => _profitText(t, d.profit),
    fmt(report.closedProfit),
  ),
  if (report.showNetProfit) ...[
    ReportColSpec(
      'ค่าใช้จ่าย',
      80,
      (d) => Text(fmt(d.expenses + d.fixed)),
      fmt(report.closedSpend),
    ),
    ReportColSpec(
      'กำไรสุทธิ',
      86,
      (d) => _profitText(t, d.netProfit),
      fmt(report.closedNetProfit),
    ),
  ],
  ReportColSpec(
    'ต้นทุน/หัว',
    80,
    (d) => Text(fmt(d.costPerHead, 2)),
    report.closedCostPerHead != null ? fmt(report.closedCostPerHead, 2) : '–',
  ),
  ReportColSpec(
    'Food cost',
    80,
    (d) => Text(d.foodPct == null ? '–' : '${fmt(d.foodPct, 1)}%'),
    report.closedFoodPct != null ? '${fmt(report.closedFoodPct, 1)}%' : '–',
  ),
];

/// Daily monthly report screen (`function ReportsView` in
/// `prototype/index.html:1585-1615` & `design/figma/report.png`).
class ReportsPage extends StatelessWidget {
  const new({super.key, this.onSelectDateForBills, this.onGoSetupCosting});

  final ValueChanged<String>? onSelectDateForBills;
  final VoidCallback? onGoSetupCosting;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final cubit = context.read<ReportsCubit>();

    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        final rep = state.report;
        final sh = state.posState.shop;
        final monthOptions = [
          for (final m in rep.availableMonths)
            DropdownOption<String>(value: m, label: thMonth(m)),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final pad = AppDimensions.pagePadding(constraints.maxWidth);
            return SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: 'รายงานรายวัน',
                    desc:
                        '${sh.name}'
                        '${sh.branch.isNotEmpty ? " · ${sh.branch}" : ""}',
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  Toolbar(
                    end: [
                      Text(
                        'ปิดยอดแล้ว ${rep.closedDays.length}/'
                        '${rep.days.length} วัน',
                        style: tt.bodySmall?.copyWith(color: t.muted),
                      ),
                      PendingBadge(onTap: onGoSetupCosting),
                    ],
                    children: [
                      SizedBox(
                        width: 240,
                        child: Field(
                          label: 'เดือน',
                          child: Dropdown<String>(
                            key: const ValueKey('reports-month-dropdown'),
                            label: 'เดือน',
                            value: rep.selectedMonth,
                            options: monthOptions,
                            onChanged: cubit.setMonth,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  StatsGroup(
                    key: const ValueKey('reports-month-stats'),
                    children: [
                      Stat(label: 'ยอดขายทั้งเดือน', value: baht(rep.totalNet)),
                      Stat(
                        label: 'ต้นทุนวัตถุดิบ',
                        value: baht(rep.closedIngCost),
                      ),
                      Stat(
                        label: 'กำไรขั้นต้น',
                        value: baht(rep.closedProfit),
                        tone: rep.closedProfit >= 0
                            ? StatTone.green
                            : StatTone.red,
                      ),
                      if (rep.showNetProfit)
                        Stat(
                          label: 'กำไรสุทธิ (ประมาณ)',
                          value: baht(rep.closedNetProfit),
                          tone: rep.closedNetProfit >= 0
                              ? StatTone.green
                              : StatTone.red,
                          sub: 'ค่าใช้จ่าย ${baht(rep.closedSpend)}',
                        ),
                      Stat(
                        label: 'ซื้อของเข้า',
                        value: baht(rep.totalPurchases),
                        sub: 'เงินที่จ่ายออกจริง',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  DailyReportTable(report: rep, onDayTap: onSelectDateForBills),
                  const SizedBox(height: AppDimensions.space4),
                  Text(
                    'ซื้อเข้า ≠ ต้นทุน: ซื้อเข้าคือเงินที่จ่ายออกวันนั้น '
                    'ส่วนต้นทุนคือมูลค่าวัตถุดิบที่ใช้ไปจริง '
                    '(ยกมา + ซื้อเข้า − เหลือ) · ค่าใช้จ่าย = รายวัน + '
                    'ค่าคงที่รายเดือนเฉลี่ยต่อวันที่เปิดร้าน',
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
