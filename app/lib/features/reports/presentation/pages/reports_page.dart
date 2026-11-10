import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:app/features/reports/presentation/widgets/daily_report_table.dart';
import 'package:app/features/reports/presentation/widgets/sales_tax_report_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/reports/presentation/cubit/reports_cubit.dart';
export 'package:app/features/reports/presentation/widgets/daily_report_table.dart';
export 'package:app/features/reports/presentation/widgets/pending_badge.dart';

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
        fmtBaht(v),
        style: TextStyle(
          color: v >= 0 ? t.successInk : t.dangerInk,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );

/// Builds metric columns for [DailyReportTable].
List<ReportColSpec> buildReportColumns(
  MonthlyReportSummary report,
  AppTokens t, [
  String? colMode,
]) {
  final mode = colMode ?? 'all';
  final showSales = mode == 'all' || mode == 'sales';
  final showProfit = mode == 'all' || mode == 'profit';
  ReportColSpec col(
    String l,
    double w,
    Widget Function(LedgerDaySummary) c,
    String f,
  ) => ReportColSpec(l, w, c, f);
  ReportColSpec numCol(
    String l,
    double w,
    double? Function(LedgerDaySummary) v,
    double tot,
  ) => col(
    l,
    w,
    (d) => Text(
      fmtBaht(v(d)),
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
    ),
    fmtBaht(tot),
  );

  return <ReportColSpec>[
    col('บิล', 56, (d) => Text('${d.bills}'), '${report.totalBills}'),
    col('หัว', 62, (d) => Text('${d.heads}'), '${report.totalHeads}'),
    if (showSales) ...[
      numCol('บุฟเฟต์', 96, (d) => d.buffetNet, report.totalBuffetNet),
      numCol('ขายเสริม', 96, (d) => d.addonNet, report.totalAddonNet),
    ],
    numCol('รวมขาย', 90, (d) => d.net, report.totalNet),
    if (showSales)
      numCol('ซื้อเข้า', 80, (d) => d.purchases, report.totalPurchases),
    numCol('ต้นทุนวัตถุดิบ', 96, (d) => d.ingCost, report.closedIngCost),
    if (showProfit)
      numCol(
        'ต้นทุนเครื่องดื่ม',
        106,
        (d) => d.addonCost,
        report.closedAddonCost,
      ),
    col(
      'กำไรขั้นต้น',
      92,
      (d) => _profitText(t, d.profit),
      fmtBaht(report.closedProfit),
    ),
    if (showProfit && report.showNetProfit) ...[
      numCol('ค่าใช้จ่าย', 76, (d) => d.expenses + d.fixed, report.closedSpend),
      col(
        'กำไรสุทธิ',
        82,
        (d) => _profitText(t, d.netProfit),
        fmtBaht(report.closedNetProfit),
      ),
    ],
    if (showProfit) ...[
      col(
        'ต้นทุน/หัว',
        76,
        (d) => Text(fmtBaht(d.costPerHead, 2)),
        report.closedCostPerHead != null
            ? fmtBaht(report.closedCostPerHead, 2)
            : '–',
      ),
      col(
        'Food cost',
        76,
        (d) => Text(d.foodPct == null ? '–' : '${fmt(d.foodPct, 1)}%'),
        report.closedFoodPct != null ? '${fmt(report.closedFoodPct, 1)}%' : '–',
      ),
    ],
  ];
}

/// Builds the month dropdown (`reports-month-dropdown`) for `/reports`.
Widget buildReportsMonthDropdown(ReportsCubit cubit) => SizedBox(
  width: 210,
  child: Dropdown<String>(
    key: const ValueKey('reports-month-dropdown'),
    label: 'เดือน',
    value: cubit.state.report.selectedMonth,
    options: [
      for (final m in cubit.state.report.availableMonths)
        DropdownOption<String>(value: m, label: thMonth(m)),
    ],
    onChanged: cubit.setMonth,
  ),
);

/// Daily monthly report screen (`ReportsView` in `prototype/index.html`).
class ReportsPage extends StatefulWidget {
  const new({super.key, this.onSelectDateForBills, this.onGoSetupCosting});
  final ValueChanged<String>? onSelectDateForBills;
  final VoidCallback? onGoSetupCosting;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _colMode = 'all';
  final _taxExport = ValueNotifier<VoidCallback?>(null);

  @override
  void dispose() {
    _taxExport.dispose();
    super.dispose();
  }

  void _setColMode(String mode) => setState(() {
    _colMode = mode;
    _taxExport.value = null;
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final cubit = context.read<ReportsCubit>();

    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        final rep = state.report;
        final repo = context.read<PosRepository>();
        final showTax = canSeeSalesTaxTab(repo);
        final taxTab = showTax && _colMode == 'tax';
        final shop = state.posState.shop;
        final d = parseKey('${rep.selectedMonth}-01');
        final mDays = DateTime(d.year, d.month + 1, 0).day;
        final divTxt = shop.fixedCostDivisor == 'calendar'
            ? 'ตามปฏิทิน ${thMonth(rep.selectedMonth)} ($mDays วัน)'
            : 'ต่อวันที่เปิดร้าน (${shop.openDaysPerMonth} วัน)';
        final partialFixed =
            rep.showNetProfit && rep.fixedDeducted + 0.01 < rep.fixedFullMonth;
        final closedLbl =
            'ปิดยอดแล้ว ${rep.closedDays.length}/${rep.days.length} วัน';
        final hasClosed = rep.closedDays.isNotEmpty;
        final dailyExp = rep.closedSpend - rep.fixedDeducted;
        StatTone pTone(double v) => !hasClosed
            ? StatTone.neutral
            : (v >= 0 ? StatTone.green : StatTone.red);

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
                      if (partialFixed)
                        const Pill(
                          key: ValueKey('reports-partial-fixed-pill'),
                          tone: PillTone.orange,
                          label: 'หักค่าคงที่ยังไม่ครบเดือน',
                        ),
                      if (taxTab) salesTaxExportButton(_taxExport),
                      PendingBadge(onTap: widget.onGoSetupCosting),
                    ],
                    children: [
                      if (isMobile) buildReportsMonthDropdown(cubit),
                      Seg<String>(
                        key: const ValueKey('reports-col-mode-seg'),
                        value: _colMode,
                        items: [
                          const SegItem(value: 'all', label: 'ทุกคอลัมน์'),
                          const SegItem(
                            value: 'profit',
                            label: 'กำไร & Food cost',
                          ),
                          const SegItem(
                            value: 'sales',
                            label: 'ยอดขาย & ซื้อเข้า',
                          ),
                          if (showTax)
                            const SegItem(value: 'tax', label: 'ภาษีขาย'),
                        ],
                        onChanged: _setColMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  if (taxTab)
                    SalesTaxReportTab(
                      repository: repo,
                      month: rep.selectedMonth,
                      exportAction: _taxExport,
                    )
                  else ...[
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
                          value: hasClosed ? baht(rep.closedIngCost) : '–',
                          sub: 'เครื่องดื่ม ${baht(rep.closedAddonCost)}',
                        ),
                        Stat(
                          label: 'กำไรขั้นต้น',
                          value: hasClosed ? baht(rep.closedProfit) : '–',
                          tone: pTone(rep.closedProfit),
                          sub: closedLbl,
                        ),
                        if (rep.showNetProfit)
                          Stat(
                            label: 'กำไรสุทธิ (ประมาณ)',
                            value: hasClosed ? baht(rep.closedNetProfit) : '–',
                            tone: pTone(rep.closedNetProfit),
                            sub:
                                'รายวัน ${baht(dailyExp)} · '
                                'คงที่ ${baht(rep.fixedDeducted)} / '
                                '${baht(rep.fixedFullMonth)}',
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
                      colMode: _colMode,
                      onDayTap: widget.onSelectDateForBills,
                    ),
                    const SizedBox(height: AppDimensions.space4),
                    Text(
                      'ซื้อเข้า ≠ ต้นทุน: ซื้อเข้าคือเงินที่จ่ายออกวันนั้น '
                      'ส่วนต้นทุนคือมูลค่าวัตถุดิบที่ใช้ไปจริง '
                      '(ยกมา + ซื้อเข้า − เหลือ) · ค่าใช้จ่าย = รายวัน + '
                      'ค่าคงที่รายเดือนเฉลี่ย$divTxt '
                      '(ขายแล้ว ${rep.salesDays} วัน)',
                      style: tt.bodySmall?.copyWith(color: t.muted),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
