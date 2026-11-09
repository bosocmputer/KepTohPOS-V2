import 'package:app/domain/models.dart';
export 'package:app/domain/expense_record.dart';
export 'package:app/domain/models.dart' show ShiftRecord, StockLot;
export 'package:app/domain/purchase_record.dart';

/// Settled sale bill (`s.sales`) or pre-settlement POS slip (`isSlipPreview`).
class BillRecord {
  new({
    required this.id,
    required this.no,
    required this.date,
    required this.at,
    required this.tableId,
    required this.tableName,
    required this.staffId,
    required this.staffName,
    required this.packageId,
    required this.lines,
    required this.subtotal,
    required this.service,
    required this.vat,
    required this.rounding,
    required this.total,
    required this.heads,
    required this.methodId,
    required this.methodName,
    required this.methodType,
    required this.received,
    required this.change,
    this.shiftId,
    this.vatMode,
    this.vatRate,
    this.bankAccountId,
    this.bankAccountInfo,
    this.eatUntil,
    this.timeLimitMin = 0,
    this.rdMachineCode,
    this.isTaxInvoice = false,
    this.isSlipPreview = false,
    this.replacesBillId,
    this.isFullInvoice = false,
    this.buyerName,
    this.buyerTaxId,
    this.buyerBranch,
    this.buyerAddress,
    this.voided = false,
    this.voidReason,
    this.voidBy,
    this.voidAt,
  });

  factory fromJson(Map<String, dynamic> json) => BillRecord(
    id: json['id'] as String,
    no: json['no'] as String,
    date: json['date'] as String,
    at: json['at'] as String,
    tableId: (json['tableId'] as String?) ?? '-',
    tableName: (json['tableName'] as String?) ?? '-',
    staffId: (json['staffId'] as String?) ?? '',
    staffName: (json['staffName'] as String?) ?? '-',
    shiftId: json['shiftId'] as String?,
    packageId: (json['packageId'] as String?) ?? '',
    lines: ((json['lines'] as List<dynamic>?) ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(OrderLineItem.fromJson)
        .toList(),
    subtotal: (json['subtotal'] as num).toInt(),
    service: (json['service'] as num?)?.toInt() ?? 0,
    vat: (json['vat'] as num?)?.toInt() ?? 0,
    rounding: (json['rounding'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num).toInt(),
    heads: HeadsCount.fromJson(
      (json['heads'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    ),
    methodId: (json['methodId'] as String?) ?? '',
    methodName: (json['methodName'] as String?) ?? '',
    methodType: (json['methodType'] as String?) ?? 'cash',
    received: (json['received'] as num).toInt(),
    change: (json['change'] as num?)?.toInt() ?? 0,
    vatMode: json['vatMode'] as String?,
    vatRate: (json['vatRate'] as num?)?.toDouble(),
    bankAccountId: json['bankAccountId'] as String?,
    bankAccountInfo: json['bankAccountInfo'] as String?,
    eatUntil: json['eatUntil'] as String?,
    timeLimitMin: (json['timeLimitMin'] as num?)?.toInt() ?? 0,
    rdMachineCode: json['rdMachineCode'] as String?,
    isTaxInvoice: (json['isTaxInvoice'] as bool?) ?? false,
    replacesBillId: json['replacesBillId'] as String?,
    isFullInvoice: (json['isFullInvoice'] as bool?) ?? false,
    buyerName: json['buyerName'] as String?,
    buyerTaxId: json['buyerTaxId'] as String?,
    buyerBranch: json['buyerBranch'] as String?,
    buyerAddress: json['buyerAddress'] as String?,
    voided: (json['voided'] as bool?) ?? false,
    voidReason: json['voidReason'] as String?,
    voidBy: json['voidBy'] as String?,
    voidAt: json['voidAt'] as String?,
  );

  final String id;
  final String no;
  final String date;
  final String at;
  String tableId;
  String tableName;
  final String staffId;
  final String staffName;
  final String? shiftId;
  final String packageId;
  final List<OrderLineItem> lines;
  final int subtotal;
  final int service;
  final int vat;
  final int rounding;
  final int total;
  final HeadsCount heads;
  final String methodId;
  final String methodName;
  final String methodType;
  final int received;
  final int change;
  final String? vatMode;
  final double? vatRate;
  final String? bankAccountId;
  final String? bankAccountInfo;
  final String? eatUntil;
  final int timeLimitMin;

  /// Settle-time snapshot: device RD machine code, tax invoice or not.
  final String? rdMachineCode;
  final bool isTaxInvoice;
  final bool isSlipPreview;

  /// Id of the voided bill this one was reissued to replace.
  final String? replacesBillId;

  /// Full tax invoice (ม.86/4) and its buyer; tax id/branch only if given.
  final bool isFullInvoice;
  final String? buyerName;
  final String? buyerTaxId;
  final String? buyerBranch;
  final String? buyerAddress;
  bool voided;
  String? voidReason;
  String? voidBy;
  String? voidAt;

  /// Seller tax id + abbreviated tax invoice lines (RD Notice 46).
  /// [replacesNo] is the voided bill's number when the caller knows it.
  List<String> taxLines(ShopConfig shop, {String? replacesNo}) => <String>[
    if (shop.taxId.isNotEmpty) 'เลขผู้เสียภาษี ${shop.taxId}',
    if (isTaxInvoice) ...<String>[
      if (shop.branchCode == '00000')
        'สำนักงานใหญ่'
      else
        'สาขาที่ ${shop.branchCode}',
      'เลขรหัสประจำเครื่อง: ${rdMachineCode ?? '-'}',
      if ((vatMode ?? shop.vatMode) == 'included') 'ราคารวมภาษีมูลค่าเพิ่มแล้ว',
    ],
    if (replacesBillId != null && replacesNo == null) 'ออกแทนฉบับเดิม',
    if (replacesBillId != null && replacesNo != null && isFullInvoice)
      'ออกแทนใบกำกับภาษีอย่างย่อ/ใบเสร็จเลขที่ $replacesNo',
    if (replacesBillId != null && replacesNo != null && !isFullInvoice)
      'ยกเลิกและออกฉบับใหม่แทนเลขที่ $replacesNo',
  ];

  BillRecord copy() => BillRecord(
    id: id,
    no: no,
    date: date,
    at: at,
    tableId: tableId,
    tableName: tableName,
    staffId: staffId,
    staffName: staffName,
    shiftId: shiftId,
    packageId: packageId,
    lines: List<OrderLineItem>.from(lines),
    subtotal: subtotal,
    service: service,
    vat: vat,
    rounding: rounding,
    total: total,
    heads: heads.copy(),
    methodId: methodId,
    methodName: methodName,
    methodType: methodType,
    received: received,
    change: change,
    vatMode: vatMode,
    vatRate: vatRate,
    bankAccountId: bankAccountId,
    bankAccountInfo: bankAccountInfo,
    eatUntil: eatUntil,
    timeLimitMin: timeLimitMin,
    rdMachineCode: rdMachineCode,
    isTaxInvoice: isTaxInvoice,
    isSlipPreview: isSlipPreview,
    replacesBillId: replacesBillId,
    isFullInvoice: isFullInvoice,
    buyerName: buyerName,
    buyerTaxId: buyerTaxId,
    buyerBranch: buyerBranch,
    buyerAddress: buyerAddress,
    voided: voided,
    voidReason: voidReason,
    voidBy: voidBy,
    voidAt: voidAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'no': no,
    'date': date,
    'at': at,
    'tableId': tableId,
    'tableName': tableName,
    'staffId': staffId,
    'staffName': staffName,
    'shiftId': shiftId,
    'packageId': packageId,
    'lines': lines.map((l) => l.toJson()).toList(),
    'subtotal': subtotal,
    'service': service,
    'vat': vat,
    'rounding': rounding,
    'total': total,
    'heads': heads.toJson(),
    'methodId': methodId,
    'methodName': methodName,
    'methodType': methodType,
    'received': received,
    'change': change,
    if (vatMode != null) 'vatMode': vatMode,
    if (vatRate != null) 'vatRate': vatRate,
    if (bankAccountId != null) 'bankAccountId': bankAccountId,
    if (bankAccountInfo != null) 'bankAccountInfo': bankAccountInfo,
    if (eatUntil != null) 'eatUntil': eatUntil,
    if (timeLimitMin > 0) 'timeLimitMin': timeLimitMin,
    if (rdMachineCode != null) 'rdMachineCode': rdMachineCode,
    if (isTaxInvoice) 'isTaxInvoice': true,
    if (replacesBillId != null) 'replacesBillId': replacesBillId,
    if (isFullInvoice) 'isFullInvoice': true,
    if (buyerName != null) 'buyerName': buyerName,
    if (buyerTaxId != null) 'buyerTaxId': buyerTaxId,
    if (buyerBranch != null) 'buyerBranch': buyerBranch,
    if (buyerAddress != null) 'buyerAddress': buyerAddress,
    'voided': voided,
    if (voidReason != null) 'voidReason': voidReason,
    if (voidBy != null) 'voidBy': voidBy,
    if (voidAt != null) 'voidAt': voidAt,
  };
}
