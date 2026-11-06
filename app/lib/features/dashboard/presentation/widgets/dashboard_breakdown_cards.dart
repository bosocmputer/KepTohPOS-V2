import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/reports/presentation/pages/reports_page.dart'
    show PendingBadge;
import 'package:flutter/material.dart';

export 'package:app/features/reports/presentation/pages/reports_page.dart'
    show PendingBadge;

/// Latest closed day hero card + unclosed-today warning banner (`today-hero`
/// in `prototype/index.html:1542-1557`).
class DashboardHeroSection extends StatelessWidget {
  const new({
    required this.summary,
    super.key,
    this.onGoStockCount,
    this.onGoSetupCosting,
  });

  final DashboardSummary summary;
  final VoidCallback? onGoStockCount;
  final VoidCallback? onGoSetupCosting;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final last = summary.lastClosedDay;
    final showNet = summary.showNetProfit;
    final lastVal = last != null ? (summary.dayMetric(last) ?? 0.0) : 0.0;
    final spendPart = showNet && last != null
        ? ' − ค่าใช้จ่าย ${baht(last.expenses + last.fixed)}'
        : '';
    final estPart = last != null && last.estItems > 0
        ? ' · มีของประมาณการ ${last.estItems} รายการ'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (last != null) ...[
          Container(
            key: const ValueKey('dashboard-hero-card'),
            padding: const EdgeInsets.all(AppDimensions.space4),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppDimensions.r),
              border: Border.all(color: t.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ปิดยอดล่าสุด · ${thDate(last.date)}'
                        '${last.isToday ? " (วันนี้)" : ""}',
                        style: tt.labelSmall?.copyWith(
                          color: t.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space1),
                      Text(
                        '${lastVal >= 0 ? "กำไร" : "ขาดทุน"} '
                        '${baht(lastVal.abs())}',
                        style: tt.displayMedium?.copyWith(
                          color: lastVal >= 0 ? t.successInk : t.dangerInk,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space1),
                      Text(
                        '${summary.fieldName} · ขาย ${baht(last.net)} − '
                        'วัตถุดิบ ${baht(last.ingCost)} − '
                        'เครื่องดื่ม ${baht(last.addonCost)}'
                        '$spendPart$estPart',
                        style: tt.bodySmall?.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.space3),
                PendingBadge(onTap: onGoSetupCosting),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space4),
        ],
        if (summary.todayOpen) ...[
          Container(
            key: const ValueKey('dashboard-today-open-banner'),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: t.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space4,
                vertical: AppDimensions.space3,
              ),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: t.primary, width: 3)),
              ),
              child: Row(
                children: [
                  const Pill(
                    label: 'วันนี้ยังไม่ปิดยอด',
                    tone: PillTone.orange,
                  ),
                  const SizedBox(width: AppDimensions.space3),
                  Expanded(
                    child: Text(
                      'วันนี้ยังไม่ได้นับของเหลือ '
                      'กำไรของวันนี้จึงยังไม่รวมในตัวเลขด้านล่าง',
                      style: tt.bodyMedium?.copyWith(color: t.ink),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space3),
                  Btn(
                    key: const ValueKey('dashboard-go-stock-btn'),
                    kind: BtnKind.primary,
                    label: 'ไปนับของเหลือ',
                    onPressed: onGoStockCount,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space4),
        ],
      ],
    );
  }
}

/// Two-column breakdown section (`ต้นทุนวัตถุดิบแยกรายการ` and
/// `ขายเสริม · เครื่องดื่ม`) in `DashboardView` (`prototype/index.html:1570-1579`).
class DashboardBreakdownGrid extends StatelessWidget {
  const new({required this.summary, super.key});

  final DashboardSummary summary;

  Widget _card(
    BuildContext context,
    String title,
    Widget table, {
    Widget? trailing,
  }) => Container(
    padding: const EdgeInsets.all(AppDimensions.space4),
    decoration: BoxDecoration(
      color: context.tokens.surface,
      borderRadius: BorderRadius.circular(AppDimensions.r),
      border: Border.all(color: context.tokens.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppDimensions.space2_5),
        table,
      ],
    ),
  );

  Widget _buildIngShareCard(BuildContext context) {
    final t = context.tokens;
    return _card(
      context,
      'ต้นทุนวัตถุดิบแยกรายการ',
      trailing: summary.ingredientShares.isNotEmpty
          ? Pill(tone: PillTone.orange, label: 'รวม ${baht(summary.ingCost)}')
          : null,
      PosDataTable<IngredientCostShareRow>(
        label: 'ต้นทุนวัตถุดิบแยกรายการ',
        rows: summary.ingredientShares,
        empty: const Empty(title: 'ยังไม่มีวันที่ปิดยอดในช่วงนี้'),
        columns: [
          DataTableCol(
            key: 'n',
            label: 'วัตถุดิบ',
            flex: 4,
            cellBuilder: (_, x) =>
                Text(x.ing.name, overflow: TextOverflow.ellipsis),
          ),
          DataTableCol(
            key: 'bar',
            label: 'สัดส่วน',
            flex: 3,
            cellBuilder: (_, x) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space2,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                child: SizedBox(
                  height: 8,
                  child: LinearProgressIndicator(
                    value: x.barRatio.clamp(0.0, 1.0),
                    backgroundColor: t.surface2,
                    valueColor: AlwaysStoppedAnimation<Color>(t.primary),
                  ),
                ),
              ),
            ),
          ),
          DataTableCol(
            key: 'v',
            label: 'บาท',
            align: ColAlign.right,
            flex: 2,
            cellBuilder: (_, x) => Text(
              fmt(x.cost),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          DataTableCol(
            key: 'p',
            label: '%',
            align: ColAlign.right,
            cellBuilder: (_, x) =>
                Text('${fmt(x.sharePct)}%', style: TextStyle(color: t.muted)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddonSalesCard(BuildContext context) {
    final t = context.tokens;
    final totalGp = summary.addonSales.fold<double>(
      0,
      (sum, x) => sum + x.grossProfit,
    );
    return _card(
      context,
      'ขายเสริม · เครื่องดื่ม',
      trailing: summary.addonSales.isNotEmpty
          ? Pill(tone: PillTone.green, label: 'กำไรรวม ${baht(totalGp)}')
          : null,
      PosDataTable<AddonSalesSummaryRow>(
        label: 'ขายเสริม',
        rows: summary.addonSales,
        empty: const Empty(title: 'ยังไม่มีการขายเสริม'),
        columns: [
          DataTableCol(
            key: 'name',
            label: 'สินค้า',
            flex: 4,
            cellBuilder: (_, x) =>
                Text(x.name, overflow: TextOverflow.ellipsis),
          ),
          DataTableCol(
            key: 'q',
            label: 'จำนวน',
            align: ColAlign.right,
            flex: 2,
            cellBuilder: (_, x) => Text(fmt(x.qty)),
          ),
          DataTableCol(
            key: 'rev',
            label: 'ยอดขาย',
            align: ColAlign.right,
            flex: 2,
            cellBuilder: (_, x) => Text(fmt(x.rev)),
          ),
          DataTableCol(
            key: 'gp',
            label: 'กำไร',
            align: ColAlign.right,
            flex: 2,
            cellBuilder: (_, x) => Text(
              fmt(x.grossProfit),
              style: TextStyle(
                color: t.successInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= 720
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildIngShareCard(context)),
              const SizedBox(width: AppDimensions.space4),
              Expanded(child: _buildAddonSalesCard(context)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildIngShareCard(context),
              const SizedBox(height: AppDimensions.space4),
              _buildAddonSalesCard(context),
            ],
          ),
  );
}
