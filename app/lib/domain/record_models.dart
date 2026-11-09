import 'package:app/domain/models.dart';
export 'package:app/domain/models.dart' show ShiftRecord, StockLot;

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
  bool voided;
  String? voidReason;
  String? voidBy;
  String? voidAt;

  /// Seller tax id + abbreviated tax invoice lines (RD Notice 46).
  List<String> taxLines(ShopConfig shop) => <String>[
    if (shop.taxId.isNotEmpty) 'เลขผู้เสียภาษี ${shop.taxId}',
    if (isTaxInvoice) ...<String>[
      if (shop.branchCode == '00000')
        'สำนักงานใหญ่'
      else
        'สาขาที่ ${shop.branchCode}',
      'เลขรหัสประจำเครื่อง: ${rdMachineCode ?? '-'}',
      if ((vatMode ?? shop.vatMode) == 'included') 'ราคารวมภาษีมูลค่าเพิ่มแล้ว',
    ],
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
    'voided': voided,
    if (voidReason != null) 'voidReason': voidReason,
    if (voidBy != null) 'voidBy': voidBy,
    if (voidAt != null) 'voidAt': voidAt,
  };
}

/// Line item inside a purchase bill.
class PurchaseLine {
  const new({required this.ingId, required this.qty, required this.total});
  factory fromJson(Map<String, dynamic> j) => PurchaseLine(
    ingId: j['ingId'] as String,
    qty: (j['qty'] as num).toDouble(),
    total: (j['total'] as num).toInt(),
  );
  final String ingId;
  final double qty;
  final int total;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'ingId': ingId,
    'qty': qty,
    'total': total,
  };
}

/// Morning ingredient purchase bill (`s.purchases`).
class PurchaseRecord {
  const new({
    required this.id,
    required this.date,
    required this.at,
    required this.supplierId,
    required this.lines,
    this.note = '',
  });
  factory fromJson(Map<String, dynamic> json) => PurchaseRecord(
    id: json['id'] as String,
    date: json['date'] as String,
    at: json['at'] as String,
    supplierId: (json['supplierId'] as String?) ?? '',
    lines: ((json['lines'] as List<dynamic>?) ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(PurchaseLine.fromJson)
        .toList(),
    note: (json['note'] as String?) ?? '',
  );
  final String id;
  final String date;
  final String at;
  final String supplierId;
  final List<PurchaseLine> lines;
  final String note;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'date': date,
    'at': at,
    'supplierId': supplierId,
    'lines': lines.map((l) => l.toJson()).toList(),
    'note': note,
  };
}

/// Daily operating expense (`s.expenses`).
class ExpenseRecord {
  const new({
    required this.id,
    required this.date,
    required this.at,
    required this.typeId,
    required this.amount,
    this.note = '',
  });
  factory fromJson(Map<String, dynamic> json) => ExpenseRecord(
    id: json['id'] as String,
    date: json['date'] as String,
    at: json['at'] as String,
    typeId: json['typeId'] as String,
    amount: (json['amount'] as num).toInt(),
    note: (json['note'] as String?) ?? '',
  );
  final String id;
  final String date;
  final String at;
  final String typeId;
  final int amount;
  final String note;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'date': date,
    'at': at,
    'typeId': typeId,
    'amount': amount,
    'note': note,
  };
}
