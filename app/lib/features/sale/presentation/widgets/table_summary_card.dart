import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

/// Thermal-style summary card showing all sub-bills, voided bills (struck
/// through), merged line items, eat-until time, and net table total
/// (`ใบสรุปยอดโต๊ะ`).
class TableSummaryCard extends StatelessWidget {
  const new({required this.shop, required this.summary, super.key});

  final ShopConfig shop;
  final TableSummarySlip summary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final h = summary.heads;
    final isLate = summary.timer.late;
    final limTxt = formatTimeLimitLabel(summary.timeLimitMin);
    final voidSub = summary.voidedCount > 0
        ? ' · ยกเลิก ${summary.voidedCount}'
        : '';

    return Container(
      key: const ValueKey('table-summary-card'),
      padding: const EdgeInsets.all(AppDimensions.space4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: BrandLogo(
              size: AppDimensions.space10,
              logoDataUrl: shop.logoDataUrl,
            ),
          ),
          const SizedBox(height: AppDimensions.space1_5),
          Text(
            shop.name,
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final info in <String>[
            if (shop.branch.isNotEmpty) shop.branch,
            if (shop.address.isNotEmpty) shop.address,
            if (shop.phone.isNotEmpty) 'โทร ${shop.phone}',
          ])
            Text(
              info,
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(color: t.muted),
            ),
          const SizedBox(height: AppDimensions.space2),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space2),
          Text(
            key: const ValueKey('table-summary-title'),
            'ใบสรุปยอดโต๊ะ (ไม่ใช่ใบกำกับภาษี)',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: t.primaryInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.space1_5),
          _row(
            t,
            tt,
            'โต๊ะ ${summary.tableName}',
            'เปิดโต๊ะ ${thTime(summary.openedAt)} น.',
          ),
          Text(
            key: const ValueKey('table-summary-heads'),
            'ลูกค้าสุทธิ: ผู้ใหญ่ ${h.a}'
            '${h.c > 0 ? " · เด็ก ${h.c}" : ""}'
            '${h.f > 0 ? " · ฟรี ${h.f}" : ""}',
            style: tt.labelSmall?.copyWith(color: t.muted),
          ),
          if (shop.useTimer) ...[
            const SizedBox(height: AppDimensions.space1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    key: const ValueKey('summary-eat-until'),
                    summary.eatUntil != null && summary.timeLimitMin > 0
                        ? 'ทานได้ถึงเวลา ${thTime(summary.eatUntil!)} น. '
                              '(จำกัด $limTxt)'
                        : 'ไม่จำกัดเวลา',
                    style: tt.labelSmall?.copyWith(
                      color: summary.timeLimitMin > 0 ? t.primaryInk : t.muted,
                      fontWeight: summary.timeLimitMin > 0
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (isLate)
                  Pill(
                    key: ValueKey('summary-overtime-${summary.tableId}'),
                    tone: PillTone.red,
                    label: summary.timer.text,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppDimensions.space2),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space2),
          Text(
            'รายการบิลย่อย (${summary.bills.length} บิล$voidSub)',
            style: tt.labelSmall?.copyWith(
              color: t.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.space1),
          for (final b in summary.bills) _buildSubBillRow(t, tt, b),
          const SizedBox(height: AppDimensions.space2),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space2),
          Text(
            'รายการอาหารและเครื่องดื่มรวม',
            style: tt.labelSmall?.copyWith(
              color: t.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.space1),
          for (final l in summary.mergedLines)
            _row(
              t,
              tt,
              '${l.name} × ${l.qty}',
              baht(l.qty * l.price),
              boldRight: true,
            ),
          const SizedBox(height: AppDimensions.space2),
          Divider(color: t.line, height: 1),
          const SizedBox(height: AppDimensions.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'รวมสุทธิทั้งโต๊ะ (${summary.activeBillCount} บิล)',
                style: tt.titleMedium?.copyWith(
                  color: t.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                key: const ValueKey('table-summary-total'),
                baht(summary.total, summary.total % 100 != 0 ? 2 : 0),
                style: tt.titleLarge?.copyWith(
                  color: t.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubBillRow(AppTokens t, TextTheme tt, BillRecord b) {
    final voided = b.voided;
    final strike = voided ? TextDecoration.lineThrough : null;
    final col = voided ? t.muted : t.ink;
    return Padding(
      key: ValueKey('summary-sub-bill-${b.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceHalf),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '#${b.no} (${thTime(b.at)} น.) · ${b.methodName}',
              style: tt.bodySmall?.copyWith(color: col, decoration: strike),
            ),
          ),
          if (voided) ...[
            Pill(
              key: ValueKey('summary-bill-voided-${b.id}'),
              tone: PillTone.red,
              label: 'ยกเลิก',
            ),
            const SizedBox(width: AppDimensions.space1_5),
          ],
          Text(
            baht(b.total, b.total % 100 != 0 ? 2 : 0),
            style: tt.bodySmall?.copyWith(
              color: col,
              fontWeight: FontWeight.w700,
              decoration: strike,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    AppTokens t,
    TextTheme tt,
    String left,
    String right, {
    bool boldRight = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceHalf),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(left, style: tt.bodySmall?.copyWith(color: t.ink)),
        ),
        Text(
          right,
          style: tt.bodySmall?.copyWith(
            color: t.ink,
            fontWeight: boldRight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
