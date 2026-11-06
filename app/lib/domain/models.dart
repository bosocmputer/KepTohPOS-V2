export 'package:app/domain/entities.dart';
export 'package:app/domain/pos_state.dart';
export 'package:app/domain/record_models.dart';
export 'package:app/domain/state_models.dart';

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
