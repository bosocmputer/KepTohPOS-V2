/// Store configuration (`shop` in `prototype/data/mock-data.js`).
class ShopConfig {
  const new({
    this.name = '',
    this.branch = '',
    this.address = '',
    this.phone = '',
    this.taxId = '',
    this.promptpay = '',
    this.vatMode = 'none',
    this.servicePct = 0,
    this.defaultFloat = 1000,
    this.receiptFooter = '',
    this.useTimer = true,
    this.payTiming = 'before',
    this.costMethod = 'avg',
    this.showNetProfit = true,
    this.childHeadWeight = 0.5,
    this.openDaysPerMonth = 30,
    this.weeklyCountDow = 1,
    this.rounding = 'down',
  });

  factory fromJson(Map<String, dynamic> json) => ShopConfig(
    name: (json['name'] as String?) ?? '',
    branch: (json['branch'] as String?) ?? '',
    address: (json['address'] as String?) ?? '',
    phone: (json['phone'] as String?) ?? '',
    taxId: (json['taxId'] as String?) ?? '',
    promptpay: (json['promptpay'] as String?) ?? '',
    vatMode: (json['vatMode'] as String?) ?? 'none',
    servicePct: (json['servicePct'] as num?)?.toDouble() ?? 0,
    defaultFloat: (json['defaultFloat'] as num?)?.toDouble() ?? 1000,
    receiptFooter: (json['receiptFooter'] as String?) ?? '',
    useTimer: (json['useTimer'] as bool?) ?? true,
    payTiming: (json['payTiming'] as String?) ?? 'before',
    costMethod: (json['costMethod'] as String?) ?? 'avg',
    showNetProfit: (json['showNetProfit'] as bool?) ?? true,
    childHeadWeight: (json['childHeadWeight'] as num?)?.toDouble() ?? 0.5,
    openDaysPerMonth: (json['openDaysPerMonth'] as num?)?.toInt() ?? 30,
    weeklyCountDow: (json['weeklyCountDow'] as num?)?.toInt() ?? 1,
    rounding: (json['rounding'] as String?) ?? 'down',
  );

  final String name;
  final String branch;
  final String address;
  final String phone;
  final String taxId;
  final String promptpay;
  final String vatMode;
  final double servicePct;
  final double defaultFloat;
  final String receiptFooter;
  final bool useTimer;
  final String payTiming;
  final String costMethod;
  final bool showNetProfit;
  final double childHeadWeight;
  final int openDaysPerMonth;
  final int weeklyCountDow;
  final String rounding;

  ShopConfig copyWith({
    String? name,
    String? branch,
    String? address,
    String? phone,
    String? taxId,
    String? promptpay,
    String? vatMode,
    double? servicePct,
    double? defaultFloat,
    String? receiptFooter,
    bool? useTimer,
    String? payTiming,
    String? costMethod,
    bool? showNetProfit,
    double? childHeadWeight,
    int? openDaysPerMonth,
    int? weeklyCountDow,
    String? rounding,
  }) => ShopConfig(
    name: name ?? this.name,
    branch: branch ?? this.branch,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    taxId: taxId ?? this.taxId,
    promptpay: promptpay ?? this.promptpay,
    vatMode: vatMode ?? this.vatMode,
    servicePct: servicePct ?? this.servicePct,
    defaultFloat: defaultFloat ?? this.defaultFloat,
    receiptFooter: receiptFooter ?? this.receiptFooter,
    useTimer: useTimer ?? this.useTimer,
    payTiming: payTiming ?? this.payTiming,
    costMethod: costMethod ?? this.costMethod,
    showNetProfit: showNetProfit ?? this.showNetProfit,
    childHeadWeight: childHeadWeight ?? this.childHeadWeight,
    openDaysPerMonth: openDaysPerMonth ?? this.openDaysPerMonth,
    weeklyCountDow: weeklyCountDow ?? this.weeklyCountDow,
    rounding: rounding ?? this.rounding,
  );
}
