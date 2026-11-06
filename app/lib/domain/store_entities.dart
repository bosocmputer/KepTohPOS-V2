/// Dining table (`tables` in `mock-data.js`).
class DiningTable {
  const new({
    required this.id,
    required this.name,
    required this.seats,
    required this.zone,
  });

  factory fromJson(Map<String, dynamic> json) => DiningTable(
    id: json['id'] as String,
    name: json['name'] as String,
    seats: (json['seats'] as num).toInt(),
    zone: (json['zone'] as String?) ?? '',
  );

  final String id;
  final String name;
  final int seats;
  final String zone;

  DiningTable copyWith({String? id, String? name, int? seats, String? zone}) =>
      DiningTable(
        id: id ?? this.id,
        name: name ?? this.name,
        seats: seats ?? this.seats,
        zone: zone ?? this.zone,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'seats': seats,
    'zone': zone,
  };
}

/// Staff member (`staff` in `mock-data.js`).
class StaffMember {
  const new({
    required this.id,
    required this.name,
    required this.role,
    required this.pin,
    this.active = true,
  });

  factory fromJson(Map<String, dynamic> json) => StaffMember(
    id: json['id'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    pin: json['pin'] as String,
    active: (json['active'] as bool?) ?? true,
  );

  final String id;
  final String name;
  final String role;
  final String pin;
  final bool active;

  StaffMember copyWith({
    String? id,
    String? name,
    String? role,
    String? pin,
    bool? active,
  }) => StaffMember(
    id: id ?? this.id,
    name: name ?? this.name,
    role: role ?? this.role,
    pin: pin ?? this.pin,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'role': role,
    'pin': pin,
    'active': active,
  };
}

/// Payment method (`payments` in `mock-data.js`).
class PaymentMethod {
  const new({
    required this.id,
    required this.name,
    required this.type,
    this.active = true,
  });

  factory fromJson(Map<String, dynamic> json) => PaymentMethod(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    active: (json['active'] as bool?) ?? true,
  );

  final String id;
  final String name;
  final String type;
  final bool active;

  PaymentMethod copyWith({
    String? id,
    String? name,
    String? type,
    bool? active,
  }) => PaymentMethod(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'type': type,
    'active': active,
  };
}

/// Daily expense category (`expenseTypes` in `mock-data.js`).
class ExpenseType {
  const new({required this.id, required this.name});

  factory fromJson(Map<String, dynamic> json) =>
      ExpenseType(id: json['id'] as String, name: json['name'] as String);

  final String id;
  final String name;

  ExpenseType copyWith({String? id, String? name}) =>
      ExpenseType(id: id ?? this.id, name: name ?? this.name);

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};
}

/// Monthly fixed cost (`fixedCosts` in `mock-data.js`).
class FixedCostItem {
  const new({
    required this.id,
    required this.name,
    required this.amount,
    this.active = true,
  });

  factory fromJson(Map<String, dynamic> json) => FixedCostItem(
    id: json['id'] as String,
    name: json['name'] as String,
    amount: (json['amount'] as num).toDouble(),
    active: (json['active'] as bool?) ?? true,
  );

  final String id;
  final String name;
  final double amount;
  final bool active;

  FixedCostItem copyWith({
    String? id,
    String? name,
    double? amount,
    bool? active,
  }) => FixedCostItem(
    id: id ?? this.id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'amount': amount,
    'active': active,
  };
}
