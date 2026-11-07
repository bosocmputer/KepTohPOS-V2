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
    amount: (json['amount'] as num).toInt(),
    active: (json['active'] as bool?) ?? true,
  );

  final String id;
  final String name;
  final int amount;
  final bool active;

  FixedCostItem copyWith({
    String? id,
    String? name,
    int? amount,
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

/// Store bank account for receiving bank transfers (`shop.bankAccounts`).
class BankAccountItem {
  const new({
    required this.id,
    required this.bankName,
    required this.accountNo,
    required this.accountName,
    this.active = true,
  });

  factory fromJson(Map<String, dynamic> json) => BankAccountItem(
    id: (json['id'] as String?) ?? '',
    bankName: (json['bankName'] as String?) ?? '',
    accountNo: (json['accountNo'] as String?) ?? '',
    accountName: (json['accountName'] as String?) ?? '',
    active: (json['active'] as bool?) ?? true,
  );

  final String id;
  final String bankName;
  final String accountNo;
  final String accountName;
  final bool active;

  String get shortLabel => '$bankName · $accountNo';

  String get fullLabel =>
      accountName.trim().isEmpty ? shortLabel : '$shortLabel ($accountName)';

  BankAccountItem copyWith({
    String? id,
    String? bankName,
    String? accountNo,
    String? accountName,
    bool? active,
  }) => BankAccountItem(
    id: id ?? this.id,
    bankName: bankName ?? this.bankName,
    accountNo: accountNo ?? this.accountNo,
    accountName: accountName ?? this.accountName,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'bankName': bankName,
    'accountNo': accountNo,
    'accountName': accountName,
    'active': active,
  };
}

/// Default bank accounts seeded when `shop.bankAccounts` is not yet configured.
const List<BankAccountItem> kDefaultBankAccounts = <BankAccountItem>[
  BankAccountItem(
    id: 'ba1',
    bankName: 'ธนาคารกสิกรไทย',
    accountNo: '123-4-56789-0',
    accountName: 'จ่าโบ้หมูกะทะ',
  ),
  BankAccountItem(
    id: 'ba2',
    bankName: 'ธนาคารไทยพาณิชย์',
    accountNo: '987-6-54321-0',
    accountName: 'จ่าโบ้หมูกะทะ',
  ),
];
