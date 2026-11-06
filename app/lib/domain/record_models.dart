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
    subtotal: (json['subtotal'] as num).toDouble(),
    service: (json['service'] as num?)?.toDouble() ?? 0,
    vat: (json['vat'] as num?)?.toDouble() ?? 0,
    rounding: (json['rounding'] as num?)?.toDouble() ?? 0,
    total: (json['total'] as num).toDouble(),
    heads: HeadsCount.fromJson(
      (json['heads'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    ),
    methodId: (json['methodId'] as String?) ?? '',
    methodName: (json['methodName'] as String?) ?? '',
    methodType: (json['methodType'] as String?) ?? 'cash',
    received: (json['received'] as num).toDouble(),
    change: (json['change'] as num?)?.toDouble() ?? 0,
    vatMode: json['vatMode'] as String?,
    vatRate: (json['vatRate'] as num?)?.toDouble(),
    bankAccountId: json['bankAccountId'] as String?,
    bankAccountInfo: json['bankAccountInfo'] as String?,
    eatUntil: json['eatUntil'] as String?,
    timeLimitMin: (json['timeLimitMin'] as num?)?.toInt() ?? 0,
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
  final double subtotal;
  final double service;
  final double vat;
  final double rounding;
  final double total;
  final HeadsCount heads;
  final String methodId;
  final String methodName;
  final String methodType;
  final double received;
  final double change;
  final String? vatMode;
  final double? vatRate;
  final String? bankAccountId;
  final String? bankAccountInfo;
  final String? eatUntil;
  final int timeLimitMin;
  final bool isSlipPreview;
  bool voided;
  String? voidReason;
  String? voidBy;
  String? voidAt;

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
    total: (j['total'] as num).toDouble(),
  );
  final String ingId;
  final double qty;
  final double total;
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
    amount: (json['amount'] as num).toDouble(),
    note: (json['note'] as String?) ?? '',
  );
  final String id;
  final String date;
  final String at;
  final String typeId;
  final double amount;
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
