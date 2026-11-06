export 'package:app/domain/shop_config.dart';
export 'package:app/domain/store_entities.dart';

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

  PackageItem copyWith({
    String? id,
    String? name,
    double? adultPrice,
    double? childPrice,
    String? childRule,
    String? freeRule,
    int? timeLimit,
    bool? active,
  }) => PackageItem(
    id: id ?? this.id,
    name: name ?? this.name,
    adultPrice: adultPrice ?? this.adultPrice,
    childPrice: childPrice ?? this.childPrice,
    childRule: childRule ?? this.childRule,
    freeRule: freeRule ?? this.freeRule,
    timeLimit: timeLimit ?? this.timeLimit,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'adultPrice': adultPrice,
    'childPrice': childPrice,
    'childRule': childRule,
    'freeRule': freeRule,
    'timeLimit': timeLimit,
    'active': active,
  };
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

  AddonItem copy() => copyWith();

  AddonItem copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    double? cost,
    int? stock,
    bool? active,
  }) => AddonItem(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    price: price ?? this.price,
    cost: cost ?? this.cost,
    stock: stock ?? this.stock,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'category': category,
    'price': price,
    'cost': cost,
    'stock': stock,
    'active': active,
  };
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

  SupplierItem copyWith({
    String? id,
    String? name,
    String? phone,
    String? note,
  }) => SupplierItem(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'phone': phone,
    'note': note,
  };
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

  IngredientItem copyWith({
    String? id,
    String? name,
    String? unit,
    double? lastCost,
    double? par,
    String? supplierId,
    String? category,
    double? use,
    String? location,
    String? countFreq,
  }) => IngredientItem(
    id: id ?? this.id,
    name: name ?? this.name,
    unit: unit ?? this.unit,
    lastCost: lastCost ?? this.lastCost,
    par: par ?? this.par,
    supplierId: supplierId ?? this.supplierId,
    category: category ?? this.category,
    use: use ?? this.use,
    location: location ?? this.location,
    countFreq: countFreq ?? this.countFreq,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'unit': unit,
    'lastCost': lastCost,
    'par': par,
    'supplierId': supplierId,
    'category': category,
    'use': use,
    'location': location,
    'countFreq': countFreq,
  };
}
