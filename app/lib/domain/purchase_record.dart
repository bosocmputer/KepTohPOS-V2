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
