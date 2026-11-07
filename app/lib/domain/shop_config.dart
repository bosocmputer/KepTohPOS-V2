import 'package:app/domain/store_entities.dart';

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
    this.vatRate = 7.0,
    this.servicePct = 0,
    this.defaultFloat = 100000,
    this.receiptFooter = '',
    this.useTimer = true,
    this.payTiming = 'before',
    this.costMethod = 'avg',
    this.showNetProfit = true,
    this.childHeadWeight = 0.5,
    this.openDaysPerMonth = 30,
    this.fixedCostDivisor = 'custom',
    this.weeklyCountDow = 1,
    this.dayCutoffMinutes = 0,
    this.rounding = 'down',
    this.themeMode = 'light',
    this.themePalette = 'orange',
    this.bankAccounts = kDefaultBankAccounts,
  });

  factory fromJson(Map<String, dynamic> json) => ShopConfig(
    name: (json['name'] as String?) ?? '',
    branch: (json['branch'] as String?) ?? '',
    address: (json['address'] as String?) ?? '',
    phone: (json['phone'] as String?) ?? '',
    taxId: (json['taxId'] as String?) ?? '',
    promptpay: (json['promptpay'] as String?) ?? '',
    vatMode: (json['vatMode'] as String?) ?? 'none',
    vatRate: (json['vatRate'] as num?)?.toDouble() ?? 7.0,
    servicePct: (json['servicePct'] as num?)?.toDouble() ?? 0,
    defaultFloat: (json['defaultFloat'] as num?)?.toInt() ?? 100000,
    receiptFooter: (json['receiptFooter'] as String?) ?? '',
    useTimer: (json['useTimer'] as bool?) ?? true,
    payTiming: (json['payTiming'] as String?) ?? 'before',
    costMethod: (json['costMethod'] as String?) ?? 'avg',
    showNetProfit: (json['showNetProfit'] as bool?) ?? true,
    childHeadWeight: (json['childHeadWeight'] as num?)?.toDouble() ?? 0.5,
    openDaysPerMonth: (json['openDaysPerMonth'] as num?)?.toInt() ?? 30,
    fixedCostDivisor: (json['fixedCostDivisor'] as String?) ?? 'custom',
    weeklyCountDow: (json['weeklyCountDow'] as num?)?.toInt() ?? 1,
    dayCutoffMinutes: (json['dayCutoffMinutes'] as num?)?.toInt() ?? 0,
    rounding: (json['rounding'] as String?) ?? 'down',
    themeMode: (json['themeMode'] as String?) ?? 'light',
    themePalette: (json['themePalette'] as String?) ?? 'orange',
    bankAccounts: json['bankAccounts'] is List<dynamic>
        ? (json['bankAccounts'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(BankAccountItem.fromJson)
              .toList()
        : kDefaultBankAccounts,
  );

  final String name;
  final String branch;
  final String address;
  final String phone;
  final String taxId;
  final String promptpay;
  final String vatMode;
  final double vatRate;
  final double servicePct;
  final int defaultFloat;
  final String receiptFooter;
  final bool useTimer;
  final String payTiming;
  final String costMethod;
  final bool showNetProfit;
  final double childHeadWeight;
  final int openDaysPerMonth;
  final String fixedCostDivisor;
  final int weeklyCountDow;
  final int dayCutoffMinutes;
  final String rounding;
  final String themeMode;
  final String themePalette;
  final List<BankAccountItem> bankAccounts;

  List<BankAccountItem> get activeBankAccounts =>
      bankAccounts.where((b) => b.active).toList();

  ShopConfig copyWith({
    String? name,
    String? branch,
    String? address,
    String? phone,
    String? taxId,
    String? promptpay,
    String? vatMode,
    double? vatRate,
    double? servicePct,
    int? defaultFloat,
    String? receiptFooter,
    bool? useTimer,
    String? payTiming,
    String? costMethod,
    bool? showNetProfit,
    double? childHeadWeight,
    int? openDaysPerMonth,
    String? fixedCostDivisor,
    int? weeklyCountDow,
    int? dayCutoffMinutes,
    String? rounding,
    String? themeMode,
    String? themePalette,
    List<BankAccountItem>? bankAccounts,
  }) => ShopConfig(
    name: name ?? this.name,
    branch: branch ?? this.branch,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    taxId: taxId ?? this.taxId,
    promptpay: promptpay ?? this.promptpay,
    vatMode: vatMode ?? this.vatMode,
    vatRate: vatRate ?? this.vatRate,
    servicePct: servicePct ?? this.servicePct,
    defaultFloat: defaultFloat ?? this.defaultFloat,
    receiptFooter: receiptFooter ?? this.receiptFooter,
    useTimer: useTimer ?? this.useTimer,
    payTiming: payTiming ?? this.payTiming,
    costMethod: costMethod ?? this.costMethod,
    showNetProfit: showNetProfit ?? this.showNetProfit,
    childHeadWeight: childHeadWeight ?? this.childHeadWeight,
    openDaysPerMonth: openDaysPerMonth ?? this.openDaysPerMonth,
    fixedCostDivisor: fixedCostDivisor ?? this.fixedCostDivisor,
    weeklyCountDow: weeklyCountDow ?? this.weeklyCountDow,
    dayCutoffMinutes: dayCutoffMinutes ?? this.dayCutoffMinutes,
    rounding: rounding ?? this.rounding,
    themeMode: themeMode ?? this.themeMode,
    themePalette: themePalette ?? this.themePalette,
    bankAccounts: bankAccounts ?? this.bankAccounts,
  );

  /// Serializes this [ShopConfig] to a JSON map matching `shop.json`.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'branch': branch,
    'address': address,
    'phone': phone,
    'taxId': taxId,
    'promptpay': promptpay,
    'vatMode': vatMode,
    'vatRate': vatRate,
    'servicePct': servicePct,
    'defaultFloat': defaultFloat,
    'receiptFooter': receiptFooter,
    'useTimer': useTimer,
    'payTiming': payTiming,
    'costMethod': costMethod,
    'showNetProfit': showNetProfit,
    'childHeadWeight': childHeadWeight,
    'openDaysPerMonth': openDaysPerMonth,
    'fixedCostDivisor': fixedCostDivisor,
    'weeklyCountDow': weeklyCountDow,
    'dayCutoffMinutes': dayCutoffMinutes,
    'rounding': rounding,
    'themeMode': themeMode,
    'themePalette': themePalette,
    'bankAccounts': bankAccounts.map((b) => b.toJson()).toList(),
  };
}
