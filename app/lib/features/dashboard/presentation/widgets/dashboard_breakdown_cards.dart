import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
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
    final lastVal = last != null ? (summary.dayMetric(last) ?? 0.0) : 0.0;
    final spendPart = summary.showNetProfit && last != null
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppDimensions.r),
              border: Border.all(color: t.line),
            ),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        'ปิดยอดล่าสุด · ${thDate(last.date)}'
                        '${last.isToday ? " (วันนี้)" : ""}',
                        style: tt.labelSmall?.copyWith(
                          color: t.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${lastVal >= 0 ? "กำไร" : "ขาดทุน"} '
                        '${baht(lastVal.abs())}',
                        style: tt.displayMedium?.copyWith(
                          color: lastVal >= 0 ? t.successInk : t.dangerInk,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                PendingBadge(onTap: onGoSetupCosting),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: t.primary, width: 3)),
              ),
              child: Row(
                spacing: 12,
                children: [
                  const Pill(
                    label: 'วันนี้ยังไม่ปิดยอด',
                    tone: PillTone.orange,
                  ),
                  Expanded(
                    child: Text(
                      'วันนี้ยังไม่ได้นับของเหลือ '
                      'กำไรของวันนี้จึงยังไม่รวมในตัวเลขด้านล่าง',
                      style: tt.bodyMedium?.copyWith(color: t.ink),
                    ),
                  ),
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
          const SizedBox(height: 16),
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
    BuildContext ctx,
    String title,
    Widget table, [
    Widget? trailing,
  ]) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ctx.tokens.surface,
      borderRadius: BorderRadius.circular(AppDimensions.r),
      border: Border.all(color: ctx.tokens.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            ),
            ?trailing,
          ],
        ),
        table,
      ],
    ),
  );

  DataTableCol<T> _col<T>(
    String k,
    String l,
    Widget Function(T) b, [
    int flex = 1,
    ColAlign align = ColAlign.left,
  ]) => DataTableCol(
    key: k,
    label: l,
    flex: flex,
    align: align,
    cellBuilder: (_, x) => b(x),
  );

  Widget _progressBar(AppTokens t, double ratio) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: LinearProgressIndicator(
          value: ratio.clamp(0.0, 1.0),
          backgroundColor: t.surface2,
          valueColor: AlwaysStoppedAnimation<Color>(t.primary),
        ),
      ),
    ),
  );

  Widget _buildIngShareCard(BuildContext context) {
    final t = context.tokens;
    const bold = TextStyle(fontWeight: FontWeight.w600);
    return _card(
      context,
      'ต้นทุนวัตถุดิบแยกรายการ',
      PosDataTable<IngredientCostShareRow>(
        label: 'ต้นทุนวัตถุดิบแยกรายการ',
        rows: summary.ingredientShares,
        empty: const Empty(title: 'ยังไม่มีวันที่ปิดยอดในช่วงนี้'),
        columns: [
          _col(
            'n',
            'วัตถุดิบ',
            (x) => Text(x.ing.name, overflow: TextOverflow.ellipsis),
            4,
          ),
          _col('bar', 'สัดส่วน', (x) => _progressBar(t, x.barRatio), 3),
          _col(
            'v',
            'บาท',
            (x) => Text(fmtBaht(x.cost), style: bold),
            2,
            ColAlign.right,
          ),
          _col(
            'p',
            '%',
            (x) =>
                Text('${fmt(x.sharePct)}%', style: TextStyle(color: t.muted)),
            1,
            ColAlign.right,
          ),
        ],
      ),
      summary.ingredientShares.isNotEmpty
          ? Pill(tone: PillTone.orange, label: 'รวม ${baht(summary.ingCost)}')
          : null,
    );
  }

  Widget _buildAddonSalesCard(BuildContext context) {
    final t = context.tokens;
    final totalGp = summary.addonSales.fold<double>(
      0,
      (sum, x) => sum + x.grossProfit,
    );
    final gpText = TextStyle(color: t.successInk, fontWeight: FontWeight.w600);
    return _card(
      context,
      'ขายเสริม · เครื่องดื่ม',
      PosDataTable<AddonSalesSummaryRow>(
        label: 'ขายเสริม',
        rows: summary.addonSales,
        empty: const Empty(title: 'ยังไม่มีการขายเสริม'),
        columns: [
          _col(
            'name',
            'สินค้า',
            (x) => Text(x.name, overflow: TextOverflow.ellipsis),
            4,
          ),
          _col('q', 'จำนวน', (x) => Text(fmt(x.qty)), 2, ColAlign.right),
          _col('rev', 'ยอดขาย', (x) => Text(fmtBaht(x.rev)), 2, ColAlign.right),
          _col(
            'gp',
            'กำไร',
            (x) => Text(fmtBaht(x.grossProfit), style: gpText),
            2,
            ColAlign.right,
          ),
        ],
      ),
      summary.addonSales.isNotEmpty
          ? Pill(tone: PillTone.green, label: 'กำไรรวม ${baht(totalGp)}')
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ing = _buildIngShareCard(context);
    final add = _buildAddonSalesCard(context);
    return LayoutBuilder(
      builder: (_, c) => c.maxWidth >= 720
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                for (final w in [ing, add]) Expanded(child: w),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [ing, add],
            ),
    );
  }
}
