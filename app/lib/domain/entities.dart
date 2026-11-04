export 'package:app/domain/shop_config.dart';

/// Buffet package (`packages` in `mock-data.js`).
class PackageItem {
  const new({
    required this.id,
    required this.name,
    required this.adultPrice,
    required this.childPrice,
    this.childRule = '',
    this.freeRule = '',
    this.timeLimit = 0,
    this.active = true,
  });

  factory fromJson(Map<String, dynamic> json) => PackageItem(
    id: json['id'] as String,
    name: json['name'] as String,
    adultPrice: (json['adultPrice'] as num).toDouble(),
    childPrice: (json['childPrice'] as num).toDouble(),
    childRule: (json['childRule'] as String?) ?? '',
    freeRule: (json['freeRule'] as String?) ?? '',
    timeLimit: (json['timeLimit'] as num?)?.toInt() ?? 0,
    active: (json['active'] as bool?) ?? true,
  );

  final String id;
  final String name;
  final double adultPrice;
  final double childPrice;
  final String childRule;
  final String freeRule;
  final int timeLimit;
  final bool active;
}

/// Addon / beverage item (`addons` in `mock-data.js`).
class AddonItem {
  new({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.cost,
    required this.stock,
    this.active = true,
  });

  factory fromJson(Map<String, dynamic> json) => AddonItem(
    id: json['id'] as String,
    name: json['name'] as String,
    category: (json['category'] as String?) ?? '',
    price: (json['price'] as num).toDouble(),
    cost: (json['cost'] as num).toDouble(),
    stock: (json['stock'] as num).toInt(),
    active: (json['active'] as bool?) ?? true,
  );

  final String id;
  final String name;
  final String category;
  final double price;
  final double cost;
  int stock;
  final bool active;

  AddonItem copy() => AddonItem(
    id: id,
    name: name,
    category: category,
    price: price,
    cost: cost,
    stock: stock,
    active: active,
  );
}

/// Supplier (`suppliers` in `mock-data.js`).
class SupplierItem {
  const new({
    required this.id,
    required this.name,
    this.phone = '',
    this.note = '',
  });

  factory fromJson(Map<String, dynamic> json) => SupplierItem(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: (json['phone'] as String?) ?? '',
    note: (json['note'] as String?) ?? '',
  );

  final String id;
  final String name;
  final String phone;
  final String note;
}

/// Raw ingredient (`ingredients` in `mock-data.js`).
class IngredientItem {
  const new({
    required this.id,
    required this.name,
    required this.unit,
    required this.lastCost,
    required this.par,
    required this.supplierId,
    required this.category,
    required this.use,
    this.location = 'dry',
    this.countFreq = 'daily',
  });

  factory fromJson(Map<String, dynamic> json) => IngredientItem(
    id: json['id'] as String,
    name: json['name'] as String,
    unit: json['unit'] as String,
    lastCost: (json['lastCost'] as num).toDouble(),
    par: (json['par'] as num).toDouble(),
    supplierId: (json['supplierId'] as String?) ?? '',
    category: (json['category'] as String?) ?? '',
    use: (json['use'] as num?)?.toDouble() ?? 0,
    location: (json['location'] as String?) ?? 'dry',
    countFreq: (json['countFreq'] as String?) ?? 'daily',
  );

  final String id;
  final String name;
  final String unit;
  final double lastCost;
  final double par;
  final String supplierId;
  final String category;
  final double use;
  final String location;
  final String countFreq;
}

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
}

/// Daily expense category (`expenseTypes` in `mock-data.js`).
class ExpenseType {
  const new({required this.id, required this.name});

  factory fromJson(Map<String, dynamic> json) =>
      ExpenseType(id: json['id'] as String, name: json['name'] as String);

  final String id;
  final String name;
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
}
