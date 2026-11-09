import 'dart:async';

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/download_file_stub.dart'
    if (dart.library.js_interop) 'package:app/core/utils/download_file_web.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/utils/thai_tax.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Sales-tax tab is for VAT shops, owner/manager only.
bool canSeeSalesTaxTab(PosRepository repo) {
  final role = repo.currentStaff?.role;
  return repo.state.shop.vatRegistered &&
      (role == 'owner' || role == 'manager');
}

/// Monthly sales-tax report (ภาษีขาย) tab body with the daily per-device
/// summary. [month] is a `YYYY-MM` key owned by the reports page.
class SalesTaxReportTab extends StatefulWidget {
  const new({
    required this.repository,
    required this.month,
    required this.exportAction,
    super.key,
  });

  final PosRepository repository;
  final String month;
  final ValueNotifier<VoidCallback?> exportAction;

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
      widget.exportAction.value = _export;
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
      buildSalesTaxCsv(_rows ?? const [], _daily),
    );
  }

  Widget _scroll(Widget table) => LayoutBuilder(
    builder: (_, c) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: c.maxWidth < 1280 ? 1280 : c.maxWidth,
        child: table,
      ),
    ),
  );

  DataTableCol<T> _cell<T>(
    String label,
    Widget Function(BuildContext, T) cell, {
    int flex = 1,
    double? width,
    bool num = false,
  }) => DataTableCol<T>(
    key: label,
    label: label,
    flex: flex,
    width: width,
    align: num ? ColAlign.right : ColAlign.left,
    cellBuilder: (c, r) {
      final voided = r is SalesTaxRow && r.voided;
      return Padding(
        padding: const EdgeInsets.only(right: AppDimensions.space2_5),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: voided ? c.tokens.muted : null,
            decoration: voided && num ? TextDecoration.lineThrough : null,
            fontFeatures: num ? const [FontFeature.tabularFigures()] : null,
          ),
          child: cell(c, r),
        ),
      );
    },
  );

  DataTableCol<T> _col<T>(
    String label,
    String Function(T) text, {
    int flex = 1,
    bool num = false,
  }) => _cell<T>(label, (_, r) => Text(text(r)), flex: flex, num: num);

  Widget _docPill(SalesTaxRow r) => Pill(
    tone: r.docType == 'full' ? PillTone.green : PillTone.neutral,
    label: switch (r.docType) {
      'abb' => 'ย่อ',
      'full' => 'เต็ม',
      _ => 'ใบเสร็จ',
    },
  );

  TextStyle? _muted(BuildContext c) =>
      Theme.of(c).textTheme.bodySmall?.copyWith(color: c.tokens.muted);

  Widget _note(BuildContext context, SalesTaxRow r) {
    return Wrap(
      spacing: AppDimensions.space1_5,
      children: [
        if (r.voided) ...[
          const Pill(tone: PillTone.red, label: 'ยกเลิก'),
          if (r.voidReason?.isNotEmpty ?? false)
            Text(r.voidReason!, style: _muted(context)),
        ],
        if (r.replacesNo != null)
          Text('แทนเลขที่ ${r.replacesNo}', style: _muted(context)),
      ],
    );
  }

  Widget _buyer(BuildContext context, SalesTaxRow r) {
    final ids = [
      if (r.buyerTaxId?.isNotEmpty ?? false) r.buyerTaxId!,
      if (r.buyerBranch != null) branchLabel(r.buyerBranch!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text((r.buyerName ?? '').isEmpty ? '–' : r.buyerName!),
        if (ids.isNotEmpty) Text(ids.join(' · '), style: _muted(context)),
      ],
    );
  }

  DataTableCol<SalesTaxRow> _amt(
    String label,
    int Function(SalesTaxRow) f,
    double width,
  ) => _cell<SalesTaxRow>(
    label,
    (_, r) => Text(baht(f(r), 2)),
    width: width,
    num: true,
  );

  Widget _stats(List<SalesTaxRow> rows) {
    final live = rows.where((r) => !r.voided);
    int sum(int Function(SalesTaxRow) f) => live.fold(0, (a, r) => a + f(r));
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
          sub: 'ยกเลิก ${rows.length - live.length} ใบ',
        ),
      ],
    );
  }

  Widget _invoices(List<SalesTaxRow> rows) => _scroll(
    PosDataTable<SalesTaxRow>(
      rows: rows,
      empty: const Empty(title: 'ไม่มีใบกำกับภาษีในเดือนนี้'),
      columns: [
        _cell<SalesTaxRow>(
          'วันที่',
          (_, r) => Text(r.businessDate),
          width: 104,
        ),
        _cell<SalesTaxRow>(
          'เลขที่',
          (_, r) => Text(r.no, softWrap: false),
          width: 200,
        ),
        _cell<SalesTaxRow>('ประเภท', (_, r) => _docPill(r), width: 88),
        _cell<SalesTaxRow>('ผู้ซื้อ', _buyer, flex: 3),
        _amt('มูลค่า', (r) => r.base, 112),
        _amt('VAT', (r) => r.vat, 100),
        _amt('รวม', (r) => r.total, 120),
        _cell<SalesTaxRow>('', (_, _) => const SizedBox(), width: 12),
        _cell<SalesTaxRow>('หมายเหตุ', _note, flex: 3),
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
    if (_error != null) {
      return Empty(
        key: const ValueKey('sales-tax-error'),
        title: 'ดูรายงานภาษีขายไม่ได้',
        text: _error,
      );
    }
    if (rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stats(rows),
        const SizedBox(height: AppDimensions.space4),
        _invoices(rows),
        const SizedBox(height: AppDimensions.space6),
        Text(
          'สรุปรายวันรายเครื่อง',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppDimensions.space3),
        _devices(),
      ],
    );
  }
}

/// Toolbar CSV button; enabled once [action] is set.
Widget salesTaxExportButton(ValueListenable<VoidCallback?> action) =>
    ValueListenableBuilder<VoidCallback?>(
      valueListenable: action,
      builder: (_, fn, _) => Btn(
        key: const ValueKey('sales-tax-export'),
        label: 'ส่งออก CSV',
        disabled: fn == null,
        onPressed: fn,
      ),
    );
