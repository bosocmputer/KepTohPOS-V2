import 'dart:async';

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/download_file_stub.dart'
    if (dart.library.js_interop) 'package:app/core/utils/download_file_web.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Entry button on `/reports`; only for owner/manager of a VAT shop.
class SalesTaxReportButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PosRepository>();
    final role = repo.currentStaff?.role;
    if (!repo.state.shop.vatRegistered ||
        (role != 'owner' && role != 'manager')) {
      return const SizedBox.shrink();
    }
    return Btn(
      key: const ValueKey('sales-tax-report-button'),
      label: 'รายงานภาษีขาย',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SalesTaxReportPage(repository: repo),
        ),
      ),
    );
  }
}

/// Monthly sales-tax report (ภาษีขาย) and daily per-device summary.
class SalesTaxReportPage extends StatefulWidget {
  const new({required this.repository, super.key, this.now});

  final PosRepository repository;
  final DateTime? now;

  @override
  State<SalesTaxReportPage> createState() => _SalesTaxReportPageState();
}

class _SalesTaxReportPageState extends State<SalesTaxReportPage> {
  late final List<String> _months;
  late String _month;
  List<SalesTaxRow>? _rows;
  List<DeviceDaySummary> _daily = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = widget.now ?? DateTime.now();
    _months = [
      for (var i = 0; i < 12; i++)
        () {
          final d = DateTime(n.year, n.month - i);
          return '${d.year}-${d.month.toString().padLeft(2, '0')}';
        }(),
    ];
    _month = _months.first;
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _rows = null;
      _error = null;
    });
    final y = int.parse(_month.substring(0, 4));
    final m = int.parse(_month.substring(5));
    final last = DateTime(y, m + 1, 0).day;
    try {
      final rows = await widget.repository.getSalesTaxReport(_month);
      final daily = await widget.repository.getDailyDeviceSummary(
        '$_month-01',
        '$_month-${last.toString().padLeft(2, '0')}',
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _daily = daily;
      });
    } on PosCommandException catch (e) {
      if (!mounted) return;
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
      'sales-tax-$branch-$_month.csv',
      buildSalesTaxCsv(_rows!, _daily),
    );
  }

  static const _docLabel = <String, String>{
    'abb': 'ย่อ',
    'full': 'เต็ม',
    'receipt': 'ใบเสร็จ',
  };

  Widget _table(List<String> heads, List<List<String>> body, {int from = 99}) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            for (var i = 0; i < heads.length; i++)
              DataColumn(label: Text(heads[i]), numeric: i >= from),
          ],
          rows: [
            for (final r in body)
              DataRow(cells: [for (final c in r) DataCell(Text(c))]),
          ],
        ),
      );

  String _note(SalesTaxRow r) => [
    if (r.voided) 'ยกเลิก: ${r.voidReason ?? ''}',
    if (r.replacesNo != null) 'แทนเลขที่ ${r.replacesNo}',
  ].join(' ');

  Widget _body(BuildContext context, List<SalesTaxRow> rows) {
    final live = rows.where((r) => !r.voided);
    int sum(int Function(SalesTaxRow) f) => live.fold(0, (a, r) => a + f(r));
    final tt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รวม (ไม่รวมที่ยกเลิก): มูลค่า ${baht(sum((r) => r.base), 2)} · '
            'VAT ${baht(sum((r) => r.vat), 2)} · '
            'รวม ${baht(sum((r) => r.total), 2)}',
            key: const ValueKey('sales-tax-totals'),
            style: tt.titleSmall,
          ),
          const SizedBox(height: AppDimensions.space3),
          _table(
            const [
              'วันที่',
              'เลขที่',
              'ประเภท',
              'ผู้ซื้อ',
              'เลขผู้เสียภาษี',
              'สาขา',
              'มูลค่า',
              'VAT',
              'รวม',
              'หมายเหตุ',
            ],
            [
              for (final r in rows)
                [
                  r.businessDate,
                  r.no,
                  _docLabel[r.docType] ?? r.docType,
                  r.buyerName ?? '',
                  r.buyerTaxId ?? '',
                  r.buyerBranch ?? '',
                  baht(r.base, 2),
                  baht(r.vat, 2),
                  baht(r.total, 2),
                  _note(r),
                ],
            ],
            from: 6,
          ),
          const SizedBox(height: AppDimensions.space6),
          Text('สรุปรายวันรายเครื่อง', style: tt.titleMedium),
          _table(
            const [
              'วันที่',
              'เครื่อง',
              'รหัสเครื่อง',
              'เลขที่ตั้งแต่',
              'เลขที่ถึง',
              'จำนวน',
              'ยกเลิก',
              'มูลค่า',
              'VAT',
              'รวม',
            ],
            [
              for (final d in _daily)
                [
                  d.businessDate,
                  d.deviceCode,
                  d.rdMachineCode ?? '',
                  d.firstNo,
                  d.lastNo,
                  '${d.bills}',
                  '${d.voided}',
                  baht(d.base, 2),
                  baht(d.vat, 2),
                  baht(d.total, 2),
                ],
            ],
            from: 5,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('รายงานภาษีขาย')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.space4),
            child: Toolbar(
              end: [
                Btn(
                  key: const ValueKey('sales-tax-export'),
                  label: 'ส่งออก CSV',
                  disabled: rows == null,
                  onPressed: _export,
                ),
              ],
              children: [
                SizedBox(
                  width: 210,
                  child: Dropdown<String>(
                    key: const ValueKey('sales-tax-month'),
                    label: 'เดือน',
                    value: _month,
                    options: [
                      for (final m in _months)
                        DropdownOption<String>(value: m, label: thMonth(m)),
                    ],
                    onChanged: (m) {
                      _month = m;
                      unawaited(_load());
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Text(
                      _error!,
                      key: const ValueKey('sales-tax-error'),
                    ),
                  )
                : rows == null
                ? const Center(child: CircularProgressIndicator())
                : _body(context, rows),
          ),
        ],
      ),
    );
  }
}
