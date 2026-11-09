/// One invoice row of the monthly sales-tax report (ภาษีขาย). Money in satang.
class SalesTaxRow {
  const new({
    required this.businessDate,
    required this.at,
    required this.no,
    required this.docType,
    required this.deviceCode,
    required this.base,
    required this.vat,
    required this.total,
    required this.voided,
    this.rdMachineCode,
    this.buyerName,
    this.buyerTaxId,
    this.buyerBranch,
    this.voidReason,
    this.replacesNo,
  });

  factory fromJson(Map<String, dynamic> j) => SalesTaxRow(
    businessDate: j['business_date'] as String,
    at: j['at'] as String,
    no: j['no'] as String,
    docType: j['doc_type'] as String,
    deviceCode: j['device_code'] as String,
    rdMachineCode: j['rd_machine_code'] as String?,
    buyerName: j['buyer_name'] as String?,
    buyerTaxId: j['buyer_tax_id'] as String?,
    buyerBranch: j['buyer_branch'] as String?,
    base: (j['base'] as num).toInt(),
    vat: (j['vat'] as num).toInt(),
    total: (j['total'] as num).toInt(),
    voided: j['voided'] as bool,
    voidReason: j['void_reason'] as String?,
    replacesNo: j['replaces_no'] as String?,
  );

  final String businessDate;
  final String at;
  final String no;

  /// `abb` (ใบกำกับอย่างย่อ) | `full` (เต็มรูป) | `receipt`.
  final String docType;
  final String deviceCode;
  final String? rdMachineCode;
  final String? buyerName;
  final String? buyerTaxId;
  final String? buyerBranch;
  final int base;
  final int vat;
  final int total;
  final bool voided;
  final String? voidReason;
  final String? replacesNo;
}

/// One day x device line of the daily summary. Money in satang.
class DeviceDaySummary {
  const new({
    required this.businessDate,
    required this.deviceCode,
    required this.firstNo,
    required this.lastNo,
    required this.bills,
    required this.voided,
    required this.base,
    required this.vat,
    required this.total,
    this.rdMachineCode,
  });

  factory fromJson(Map<String, dynamic> j) => DeviceDaySummary(
    businessDate: j['business_date'] as String,
    deviceCode: j['device_code'] as String,
    rdMachineCode: j['rd_machine_code'] as String?,
    firstNo: j['first_no'] as String,
    lastNo: j['last_no'] as String,
    bills: (j['bills'] as num).toInt(),
    voided: (j['voided'] as num).toInt(),
    base: (j['base'] as num).toInt(),
    vat: (j['vat'] as num).toInt(),
    total: (j['total'] as num).toInt(),
  );

  final String businessDate;

  /// `FULL` for full tax invoices.
  final String deviceCode;
  final String? rdMachineCode;
  final String firstNo;
  final String lastNo;
  final int bills;
  final int voided;
  final int base;
  final int vat;
  final int total;
}

/// Satang as baht with 2 decimals, no grouping (`10700` -> `107.00`).
String satangToBaht2(int satang) {
  final a = satang.abs();
  final s = '${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
  return satang < 0 ? '-$s' : s;
}

/// CSV cell: quotes `" , CR LF`; text starting with `= + - @ TAB` gets a `'`
/// prefix so Excel will not run it as a formula (numbers are left as-is).
String _q(String? v) {
  var s = v ?? '';
  if (s.startsWith(RegExp('[=+\\-@\t]')) &&
      !RegExp(r'^-?\d+(\.\d+)?$').hasMatch(s)) {
    s = "'$s";
  }
  return s.contains(RegExp('[",\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

String _docLabel(String t) => switch (t) {
  'abb' => 'ย่อ',
  'full' => 'เต็ม',
  _ => 'ใบเสร็จ',
};

/// Builds the sales-tax CSV (UTF-8 BOM first): the invoice section, then the
/// daily per-device section. Voided rows carry `ยกเลิก: <reason>` and are left
/// out of the totals row.
String buildSalesTaxCsv(List<SalesTaxRow> rows, List<DeviceDaySummary> daily) {
  final b = StringBuffer('﻿')
    ..writeln('รายงานภาษีขาย')
    ..writeln(
      [
        'วันที่',
        'เลขที่',
        'ประเภท',
        'เครื่อง',
        'รหัสเครื่อง RD',
        'ผู้ซื้อ',
        'เลขประจำตัวผู้เสียภาษี',
        'สาขา',
        'มูลค่า',
        'VAT',
        'รวม',
        'หมายเหตุ',
      ].join(','),
    );
  var base = 0;
  var vat = 0;
  var total = 0;
  for (final r in rows) {
    final notes = <String>[
      if (r.voided) 'ยกเลิก: ${r.voidReason ?? ''}',
      if (r.replacesNo != null) 'แทนเลขที่ ${r.replacesNo}',
    ].join(' ');
    if (!r.voided) {
      base += r.base;
      vat += r.vat;
      total += r.total;
    }
    b.writeln(
      [
        r.businessDate,
        r.no,
        _docLabel(r.docType),
        r.deviceCode,
        r.rdMachineCode,
        r.buyerName,
        r.buyerTaxId,
        r.buyerBranch,
        satangToBaht2(r.base),
        satangToBaht2(r.vat),
        satangToBaht2(r.total),
        notes,
      ].map(_q).join(','),
    );
  }
  b
    ..writeln(
      [
        'รวม (ไม่รวมที่ยกเลิก)',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        satangToBaht2(base),
        satangToBaht2(vat),
        satangToBaht2(total),
        '',
      ].map(_q).join(','),
    )
    ..writeln()
    ..writeln('สรุปรายวันรายเครื่อง')
    ..writeln(
      [
        'วันที่',
        'เครื่อง',
        'รหัสเครื่อง RD',
        'เลขที่ตั้งแต่',
        'เลขที่ถึง',
        'จำนวน',
        'ยกเลิก',
        'มูลค่า',
        'VAT',
        'รวม',
      ].join(','),
    );
  for (final d in daily) {
    b.writeln(
      [
        d.businessDate,
        d.deviceCode,
        d.rdMachineCode,
        d.firstNo,
        d.lastNo,
        '${d.bills}',
        '${d.voided}',
        satangToBaht2(d.base),
        satangToBaht2(d.vat),
        satangToBaht2(d.total),
      ].map(_q).join(','),
    );
  }
  return b.toString();
}
