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

/// Active column preset mode for [DailyReportTable] (`all | profit | sales`).
String _activeReportColMode = 'all';

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
///
/// Column widths are calibrated so that on a 1024px tablet (`availRight=776`),
/// the first 4 sales-detail columns sum to `280px` and the remaining 9 core
/// columns (`รวมขาย` .. `Food cost`) sum to `776px`, preventing horizontal
/// scroll from slicing `รวมขาย` (`118,379`) in half at `maxScrollExtent`.
List<ReportColSpec> buildReportColumns(
  MonthlyReportSummary report,
  AppTokens t,
) {
  final mode = _activeReportColMode;
  final showSalesDetail = mode == 'all' || mode == 'sales';
  final showProfitDetail = mode == 'all' || mode == 'profit';

  return <ReportColSpec>[
    ReportColSpec('บิล', 56, (d) => Text('${d.bills}'), '${report.totalBills}'),
    ReportColSpec('หัว', 62, (d) => Text('${d.heads}'), '${report.totalHeads}'),
    if (showSalesDetail) ...[
      ReportColSpec(
        'บุฟเฟต์',
        96,
        (d) => Text(fmt(d.buffetNet)),
        fmt(report.totalBuffetNet),
      ),
      ReportColSpec(
        'ขายเสริม',
        96,
        (d) => Text(fmt(d.addonNet)),
        fmt(report.totalAddonNet),
      ),
    ],
    ReportColSpec('รวมขาย', 90, (d) => Text(fmt(d.net)), fmt(report.totalNet)),
    if (showSalesDetail)
      ReportColSpec(
        'ซื้อเข้า',
        80,
        (d) => Text(fmt(d.purchases)),
        fmt(report.totalPurchases),
      ),
    ReportColSpec(
      'ต้นทุนวัตถุดิบ',
      96,
      (d) => Text(fmt(d.ingCost)),
      fmt(report.closedIngCost),
    ),
    if (showProfitDetail)
      ReportColSpec(
        'ต้นทุนเครื่องดื่ม',
        106,
        (d) => Text(fmt(d.addonCost)),
        fmt(report.closedAddonCost),
      ),
    ReportColSpec(
      'กำไรขั้นต้น',
      92,
      (d) => _profitText(t, d.profit),
      fmt(report.closedProfit),
    ),
    if (showProfitDetail && report.showNetProfit) ...[
      ReportColSpec(
        'ค่าใช้จ่าย',
        76,
        (d) => Text(fmt(d.expenses + d.fixed)),
        fmt(report.closedSpend),
      ),
      ReportColSpec(
        'กำไรสุทธิ',
        82,
        (d) => _profitText(t, d.netProfit),
        fmt(report.closedNetProfit),
      ),
    ],
    if (showProfitDetail) ...[
      ReportColSpec(
        'ต้นทุน/หัว',
        76,
        (d) => Text(fmt(d.costPerHead, 2)),
        report.closedCostPerHead != null
            ? fmt(report.closedCostPerHead, 2)
            : '–',
      ),
      ReportColSpec(
        'Food cost',
        76,
        (d) => Text(d.foodPct == null ? '–' : '${fmt(d.foodPct, 1)}%'),
        report.closedFoodPct != null ? '${fmt(report.closedFoodPct, 1)}%' : '–',
      ),
    ],
  ];
}

/// Builds the month dropdown (`reports-month-dropdown`) for `/reports`, shown
/// in the unified Topbar on tablet/desktop and inline on mobile.
Widget buildReportsMonthDropdown(ReportsCubit cubit) {
  final rep = cubit.state.report;
  return SizedBox(
    width: 210,
    child: Dropdown<String>(
      key: const ValueKey('reports-month-dropdown'),
      label: 'เดือน',
      value: rep.selectedMonth,
      options: [
        for (final m in rep.availableMonths)
          DropdownOption<String>(value: m, label: thMonth(m)),
      ],
      onChanged: cubit.setMonth,
    ),
  );
}

/// Daily monthly report screen (`function ReportsView` in
/// `prototype/index.html:1585-1615` & `design/figma/report.png`).
class ReportsPage extends StatefulWidget {
  const new({super.key, this.onSelectDateForBills, this.onGoSetupCosting});

  final ValueChanged<String>? onSelectDateForBills;
  final VoidCallback? onGoSetupCosting;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _colMode = 'all';

  @override
  void initState() {
    super.initState();
    _activeReportColMode = _colMode;
  }

  @override
  void dispose() {
    _activeReportColMode = 'all';
    super.dispose();
  }

  void _setColMode(String mode) {
    setState(() {
      _colMode = mode;
      _activeReportColMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final cubit = context.read<ReportsCubit>();

    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        final rep = state.report;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth <= AppDimensions.mobileBp;
            final pad = AppDimensions.pagePadding(constraints.maxWidth);
            return SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Toolbar(
                    end: [
                      Pill(
                        tone: PillTone.green,
                        label:
                            'ปิดยอดแล้ว ${rep.closedDays.length}/'
                            '${rep.days.length} วัน',
                      ),
                      PendingBadge(onTap: widget.onGoSetupCosting),
                    ],
                    children: [
                      if (isMobile) buildReportsMonthDropdown(cubit),
                      Seg<String>(
                        key: const ValueKey('reports-col-mode-seg'),
                        value: _colMode,
                        items: const [
                          SegItem(value: 'all', label: 'ทุกคอลัมน์'),
                          SegItem(value: 'profit', label: 'กำไร & Food cost'),
                          SegItem(value: 'sales', label: 'ยอดขาย & ซื้อเข้า'),
                        ],
                        onChanged: _setColMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  StatsGroup(
                    key: const ValueKey('reports-month-stats'),
                    children: [
                      Stat(
                        label: 'ยอดขายทั้งเดือน',
                        value: baht(rep.totalNet),
                        sub:
                            '${rep.totalBills} บิล · '
                            '${fmt(rep.totalHeads)} หัว',
                      ),
                      Stat(
                        label: 'ต้นทุนวัตถุดิบ',
                        value: baht(rep.closedIngCost),
                        sub: 'เครื่องดื่ม ${baht(rep.closedAddonCost)}',
                      ),
                      Stat(
                        label: 'กำไรขั้นต้น',
                        value: baht(rep.closedProfit),
                        tone: rep.closedProfit >= 0
                            ? StatTone.green
                            : StatTone.red,
                        sub:
                            'ปิดยอดแล้ว ${rep.closedDays.length}/'
                            '${rep.days.length} วัน',
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
                  DailyReportTable(
                    key: ValueKey('daily-report-table-$_colMode'),
                    report: rep,
                    onDayTap: widget.onSelectDateForBills,
                  ),
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
