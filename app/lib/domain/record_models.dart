import 'package:app/domain/state_models.dart';

/// Settled sale bill (`s.sales`).
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

/// Cashier shift (`s.shifts`).
class ShiftRecord {
  new({
    required this.id,
    required this.staffId,
    required this.openedAt,
    required this.floatAmount,
    this.closedAt,
    this.counted,
    this.closedBy,
  });
  factory fromJson(Map<String, dynamic> json) => ShiftRecord(
    id: json['id'] as String,
    staffId: json['staffId'] as String,
    openedAt: json['openedAt'] as String,
    floatAmount: ((json['floatAmount'] ?? json['float']) as num).toDouble(),
    closedAt: json['closedAt'] as String?,
    counted: (json['counted'] as num?)?.toDouble(),
    closedBy: json['closedBy'] as String?,
  );
  final String id;
  final String staffId;
  final String openedAt;
  final double floatAmount;
  String? closedAt;
  double? counted;
  String? closedBy;
  ShiftRecord copy() => ShiftRecord(
    id: id,
    staffId: staffId,
    openedAt: openedAt,
    floatAmount: floatAmount,
    closedAt: closedAt,
    counted: counted,
    closedBy: closedBy,
  );
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'staffId': staffId,
    'openedAt': openedAt,
    'floatAmount': floatAmount,
    'closedAt': closedAt,
    'counted': counted,
    if (closedBy != null) 'closedBy': closedBy,
  };
}

/// Initial stock lot (`s.initialStock[ingId]`).
class StockLot {
  const new({required this.qty, required this.cost});
  factory fromJson(Map<String, dynamic> j) => StockLot(
    qty: (j['qty'] as num).toDouble(),
    cost: (j['cost'] as num).toDouble(),
  );
  final double qty;
  final double cost;
  Map<String, dynamic> toJson() => <String, dynamic>{'qty': qty, 'cost': cost};
}
