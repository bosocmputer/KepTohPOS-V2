import 'dart:async';
import 'dart:math' as math;

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/download_file_stub.dart'
    if (dart.library.js_interop) 'package:app/core/utils/download_file_web.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/utils/thai_tax.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:flutter/material.dart';

/// Whether [repo]'s current staff may open the sales-tax tab (VAT shop,
/// owner/manager only).
bool canSeeSalesTaxTab(PosRepository repo) {
  final role = repo.currentStaff?.role;
  return repo.state.shop.vatRegistered &&
      (role == 'owner' || role == 'manager');
}

/// Monthly sales-tax report (ภาษีขาย) tab body with the daily per-device
/// summary. [month] is a `YYYY-MM` key owned by the reports page.
class SalesTaxReportTab extends StatefulWidget {
  const new({required this.repository, required this.month, super.key});

  final PosRepository repository;
  final String month;

  @override
  State<SalesTaxReportTab> createState() => _SalesTaxReportTabState();
}

class _SalesTaxReportTabState extends State<SalesTaxReportTab> {
  List<SalesTaxRow>? _rows;
  List<DeviceDaySummary> _daily = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(SalesTaxReportTab old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) unawaited(_load());
  }

  Future<void> _load() async {
    final month = widget.month;
    setState(() {
      _rows = null;
      _error = null;
    });
    final last = lastDayOfMonth(
      int.parse(month.substring(0, 4)),
      int.parse(month.substring(5)),
    );
    try {
      final rows = await widget.repository.getSalesTaxReport(month);
      final daily = await widget.repository.getDailyDeviceSummary(
        '$month-01',
        '$month-${last.toString().padLeft(2, '0')}',
      );
      if (!mounted || month != widget.month) return;
      setState(() {
        _rows = rows;
        _daily = daily;
      });
    } on PosCommandException catch (e) {
      if (!mounted || month != widget.month) return;
      setState(() {
        _error = e is PosOfflineException
            ? 'ต้องออนไลน์เพื่อดูรายงานภาษีขาย'
            : e.message;
      });
    }
  }

  void _export() {
    final branch = widget.repository.state.shop.branchCode;
    downloadTextFile(
      'sales-tax-$branch-${widget.month}.csv',
      buildSalesTaxCsv(_rows!, _daily),
    );
  }

  Widget _scroll(Widget table) => LayoutBuilder(
    builder: (_, c) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: math.max(c.maxWidth, 1100), child: table),
    ),
  );

  DataTableCol<T> _col<T>(
    String label,
    String Function(T) text, {
    int flex = 1,
    bool num = false,
  }) => DataTableCol<T>(
    key: label,
    label: label,
    flex: flex,
    align: num ? ColAlign.right : ColAlign.left,
    cellBuilder: (_, r) => Text(
      text(r),
      style: num
          ? const TextStyle(fontFeatures: [FontFeature.tabularFigures()])
          : null,
    ),
  );

  Widget _docPill(SalesTaxRow r) => Pill(
    tone: switch (r.docType) {
      'full' => PillTone.green,
      'abb' => PillTone.neutral,
      _ => PillTone.orange,
    },
    label: switch (r.docType) {
      'abb' => 'ย่อ',
      'full' => 'เต็ม',
      'receipt' => 'ใบเสร็จ',
      _ => r.docType,
    },
  );

  Widget _note(BuildContext context, SalesTaxRow r) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.voided) ...[
          const Pill(tone: PillTone.red, label: 'ยกเลิก'),
          if ((r.voidReason ?? '').isNotEmpty)
            Text(r.voidReason!, style: tt.bodySmall?.copyWith(color: t.muted)),
        ],
        if (r.replacesNo != null)
          Text(
            'แทนเลขที่ ${r.replacesNo}',
            style: tt.bodySmall?.copyWith(color: t.muted),
          ),
      ],
    );
  }

  Widget _stats(List<SalesTaxRow> rows) {
    final live = rows.where((r) => !r.voided);
    int sum(int Function(SalesTaxRow) f) => live.fold(0, (a, r) => a + f(r));
    final voided = rows.length - live.length;
    return StatsGroup(
      key: const ValueKey('sales-tax-totals'),
      children: [
        Stat(
          label: 'มูลค่า (ไม่รวมยกเลิก)',
          value: baht(sum((r) => r.base), 2),
        ),
        Stat(label: 'VAT', value: baht(sum((r) => r.vat), 2)),
        Stat(label: 'รวม', value: baht(sum((r) => r.total), 2)),
        Stat(
          label: 'จำนวนใบ',
          value: '${live.length}',
          sub: 'ยกเลิก $voided ใบ',
        ),
      ],
    );
  }

  Widget _invoices(List<SalesTaxRow> rows) => _scroll(
    PosDataTable<SalesTaxRow>(
      rows: rows,
      empty: const Empty(title: 'ไม่มีใบกำกับภาษีในเดือนนี้'),
      columns: [
        _col('วันที่', (r) => r.businessDate),
        _col('เลขที่', (r) => r.no, flex: 2),
        DataTableCol<SalesTaxRow>(
          key: 'type',
          label: 'ประเภท',
          cellBuilder: (_, r) => _docPill(r),
        ),
        _col('ผู้ซื้อ', (r) => r.buyerName ?? '', flex: 2),
        _col('เลขผู้เสียภาษี', (r) => r.buyerTaxId ?? '', flex: 2),
        _col(
          'สาขา',
          (r) => r.buyerBranch == null ? '' : branchLabel(r.buyerBranch!),
        ),
        _col('มูลค่า', (r) => baht(r.base, 2), num: true),
        _col('VAT', (r) => baht(r.vat, 2), num: true),
        _col('รวม', (r) => baht(r.total, 2), num: true),
        DataTableCol<SalesTaxRow>(
          key: 'note',
          label: 'หมายเหตุ',
          flex: 2,
          cellBuilder: _note,
        ),
      ],
    ),
  );

  Widget _devices() => _scroll(
    PosDataTable<DeviceDaySummary>(
      rows: _daily,
      empty: const Empty(title: 'ไม่มีสรุปรายวันในเดือนนี้'),
      columns: [
        _col('วันที่', (d) => d.businessDate),
        _col('เครื่อง', (d) => d.deviceCode),
        _col('รหัสเครื่อง', (d) => d.rdMachineCode ?? ''),
        _col('เลขที่ตั้งแต่', (d) => d.firstNo, flex: 2),
        _col('เลขที่ถึง', (d) => d.lastNo, flex: 2),
        _col('จำนวน', (d) => '${d.bills}', num: true),
        _col('ยกเลิก', (d) => '${d.voided}', num: true),
        _col('มูลค่า', (d) => baht(d.base, 2), num: true),
        _col('VAT', (d) => baht(d.vat, 2), num: true),
        _col('รวม', (d) => baht(d.total, 2), num: true),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final tt = Theme.of(context).textTheme;
    if (_error != null) {
      return Empty(
        key: const ValueKey('sales-tax-error'),
        title: 'ดูรายงานภาษีขายไม่ได้',
        text: _error,
      );
    }
    if (rows == null) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.space6),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Toolbar(
          end: [
            Btn(
              key: const ValueKey('sales-tax-export'),
              label: 'ส่งออก CSV',
              onPressed: _export,
            ),
          ],
          children: const [],
        ),
        const SizedBox(height: AppDimensions.space4),
        _stats(rows),
        const SizedBox(height: AppDimensions.space4),
        _invoices(rows),
        const SizedBox(height: AppDimensions.space6),
        Text('สรุปรายวันรายเครื่อง', style: tt.titleMedium),
        const SizedBox(height: AppDimensions.space3),
        _devices(),
      ],
    );
  }
}
