import 'package:app/domain/entities.dart';
import 'package:app/domain/record_models.dart';
import 'package:app/domain/state_models.dart';

/// Active state of an occupied table (`openTables[tableId]`).
class OpenTableState {
  new({
    required this.openedAt,
    required this.packageId,
    this.timing = 'before',
    this.notes = '',
    List<String>? billIds,
    HeadsCount? heads,
    List<TableRound>? rounds,
    List<TableAdjustment>? adjusts,
    List<TableAdjustment>? log,
  }) : billIds = billIds ?? <String>[],
       heads = heads ?? HeadsCount(),
       rounds = rounds ?? <TableRound>[],
       adjusts = adjusts ?? <TableAdjustment>[],
       log = log ?? <TableAdjustment>[];

  factory fromJson(Map<String, dynamic> json) => OpenTableState(
    openedAt: json['openedAt'] as String,
    packageId: json['packageId'] as String,
    timing: (json['timing'] as String?) ?? 'before',
    notes: (json['notes'] as String?) ?? '',
    billIds: ((json['billIds'] as List<dynamic>?) ?? const <dynamic>[])
        .cast<String>()
        .toList(),
    heads: HeadsCount.fromJson(
      (json['heads'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    ),
    rounds: ((json['rounds'] as List<dynamic>?) ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(TableRound.fromJson)
        .toList(),
    adjusts: ((json['adjusts'] as List<dynamic>?) ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(TableAdjustment.fromJson)
        .toList(),
    log: ((json['log'] as List<dynamic>?) ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(TableAdjustment.fromJson)
        .toList(),
  );

  final String openedAt;
  final String packageId;
  String timing;
  String notes;
  final List<String> billIds;
  final HeadsCount heads;
  List<TableRound> rounds;
  List<TableAdjustment> adjusts;
  final List<TableAdjustment> log;

  OpenTableState copy() => OpenTableState(
    openedAt: openedAt,
    packageId: packageId,
    timing: timing,
    notes: notes,
    billIds: List<String>.from(billIds),
    heads: heads.copy(),
    rounds: rounds.map((r) => r.copy()).toList(),
    adjusts: List<TableAdjustment>.from(adjusts),
    log: List<TableAdjustment>.from(log),
  );

  OpenTableState freeze() => OpenTableState(
    openedAt: openedAt,
    packageId: packageId,
    timing: timing,
    notes: notes,
    billIds: List<String>.unmodifiable(billIds),
    heads: heads.freeze(),
    rounds: List<TableRound>.unmodifiable(rounds.map((r) => r.freeze())),
    adjusts: List<TableAdjustment>.unmodifiable(adjusts),
    log: List<TableAdjustment>.unmodifiable(log),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'openedAt': openedAt,
    'packageId': packageId,
    'timing': timing,
    'notes': notes,
    'billIds': billIds,
    'heads': heads.toJson(),
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'adjusts': adjusts.map((a) => a.toJson()).toList(),
    'log': log.map((l) => l.toJson()).toList(),
  };
}

/// Complete in-memory POS state (`s` in `prototype/index.html`).
class PosState {
  new({
    required this.startDate,
    required this.shop,
    required this.packages,
    required this.addons,
    required this.suppliers,
    required this.ingredients,
    required this.tables,
    required this.staff,
    required this.payments,
    required this.expenseTypes,
    required this.fixedCosts,
    this.version = 2,
    this.currentStaffId = 'st1',
    Map<String, int>? seq,
    Map<String, Map<String, double>>? counts,
    List<BillRecord>? sales,
    List<PurchaseRecord>? purchases,
    List<ShiftRecord>? shifts,
    Map<String, OpenTableState>? openTables,
    Map<String, StockLot>? initialStock,
    List<ExpenseRecord>? expenses,
  }) : seq = seq ?? <String, int>{},
       counts = counts ?? <String, Map<String, double>>{},
       sales = sales ?? <BillRecord>[],
       purchases = purchases ?? <PurchaseRecord>[],
       shifts = shifts ?? <ShiftRecord>[],
       openTables = openTables ?? <String, OpenTableState>{},
       initialStock = initialStock ?? <String, StockLot>{},
       expenses = expenses ?? <ExpenseRecord>[];

  factory fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) decode) =>
        ((json[key] as List<dynamic>?) ?? const <dynamic>[])
            .cast<Map<String, dynamic>>()
            .map(decode)
            .toList();

    final rawCounts =
        (json['counts'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final counts = rawCounts.map(
      (date, map) => MapEntry(
        date,
        (map as Map<String, dynamic>).map(
          (ingId, val) => MapEntry(ingId, (val as num).toDouble()),
        ),
      ),
    );
    final rawOpen =
        (json['openTables'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final rawInit =
        (json['initialStock'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final rawSeq =
        (json['seq'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return PosState(
      version: (json['version'] as num?)?.toInt() ?? 2,
      startDate: (json['startDate'] as String?) ?? '2026-10-05',
      currentStaffId: (json['currentStaffId'] as String?) ?? 'st1',
      shop: ShopConfig.fromJson(
        (json['shop'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      packages: parseList('packages', PackageItem.fromJson),
      addons: parseList('addons', AddonItem.fromJson),
      suppliers: parseList('suppliers', SupplierItem.fromJson),
      ingredients: parseList('ingredients', IngredientItem.fromJson),
      tables: parseList('tables', DiningTable.fromJson),
      staff: parseList('staff', StaffMember.fromJson),
      payments: parseList('payments', PaymentMethod.fromJson),
      expenseTypes: parseList('expenseTypes', ExpenseType.fromJson),
      fixedCosts: parseList('fixedCosts', FixedCostItem.fromJson),
      seq: rawSeq.map((k, v) => MapEntry(k, (v as num).toInt())),
      counts: counts,
      sales: parseList('sales', BillRecord.fromJson),
      purchases: parseList('purchases', PurchaseRecord.fromJson),
      shifts: parseList('shifts', ShiftRecord.fromJson),
      openTables: rawOpen.map(
        (k, v) =>
            MapEntry(k, OpenTableState.fromJson(v as Map<String, dynamic>)),
      ),
      initialStock: rawInit.map(
        (k, v) => MapEntry(k, StockLot.fromJson(v as Map<String, dynamic>)),
      ),
      expenses: parseList('expenses', ExpenseRecord.fromJson),
    );
  }

  int version;
  String startDate;
  String currentStaffId;
  ShopConfig shop;
  final List<PackageItem> packages;
  final List<AddonItem> addons;
  final List<SupplierItem> suppliers;
  final List<IngredientItem> ingredients;
  final List<DiningTable> tables;
  final List<StaffMember> staff;
  final List<PaymentMethod> payments;
  final List<ExpenseType> expenseTypes;
  final List<FixedCostItem> fixedCosts;
  final Map<String, int> seq;
  final Map<String, Map<String, double>> counts;
  final List<BillRecord> sales;
  final List<PurchaseRecord> purchases;
  final List<ShiftRecord> shifts;
  final Map<String, OpenTableState> openTables;
  final Map<String, StockLot> initialStock;
  final List<ExpenseRecord> expenses;

  /// Deep-copies this [PosState] so in-place domain mutations never mutate an
  /// already-emitted BLoC/Cubit state instance.
  PosState copy() => PosState(
    version: version,
    startDate: startDate,
    currentStaffId: currentStaffId,
    shop: shop.copyWith(),
    packages: List<PackageItem>.from(packages),
    addons: addons.map((a) => a.copy()).toList(),
    suppliers: List<SupplierItem>.from(suppliers),
    ingredients: List<IngredientItem>.from(ingredients),
    tables: List<DiningTable>.from(tables),
    staff: List<StaffMember>.from(staff),
    payments: List<PaymentMethod>.from(payments),
    expenseTypes: List<ExpenseType>.from(expenseTypes),
    fixedCosts: List<FixedCostItem>.from(fixedCosts),
    seq: Map<String, int>.from(seq),
    counts: counts.map((k, v) => MapEntry(k, Map<String, double>.from(v))),
    sales: sales.map((b) => b.copy()).toList(),
    purchases: List<PurchaseRecord>.from(purchases),
    shifts: shifts.map((sh) => sh.copy()).toList(),
    openTables: openTables.map((k, v) => MapEntry(k, v.copy())),
    initialStock: initialStock.map(
      (k, v) => MapEntry(k, StockLot(qty: v.qty, cost: v.cost)),
    ),
    expenses: List<ExpenseRecord>.from(expenses),
  );

  /// Returns an unmodifiable snapshot of this [PosState] where all collections
  /// and nested table states are read-only (`UnsupportedError` on mutation).
  PosState freeze() => PosState(
    version: version,
    startDate: startDate,
    currentStaffId: currentStaffId,
    shop: shop,
    packages: List<PackageItem>.unmodifiable(packages),
    addons: List<AddonItem>.unmodifiable(addons),
    suppliers: List<SupplierItem>.unmodifiable(suppliers),
    ingredients: List<IngredientItem>.unmodifiable(ingredients),
    tables: List<DiningTable>.unmodifiable(tables),
    staff: List<StaffMember>.unmodifiable(staff),
    payments: List<PaymentMethod>.unmodifiable(payments),
    expenseTypes: List<ExpenseType>.unmodifiable(expenseTypes),
    fixedCosts: List<FixedCostItem>.unmodifiable(fixedCosts),
    seq: Map<String, int>.unmodifiable(seq),
    counts: Map<String, Map<String, double>>.unmodifiable(
      counts.map((k, v) => MapEntry(k, Map<String, double>.unmodifiable(v))),
    ),
    sales: List<BillRecord>.unmodifiable(sales),
    purchases: List<PurchaseRecord>.unmodifiable(purchases),
    shifts: List<ShiftRecord>.unmodifiable(shifts),
    openTables: Map<String, OpenTableState>.unmodifiable(
      openTables.map((k, v) => MapEntry(k, v.freeze())),
    ),
    initialStock: Map<String, StockLot>.unmodifiable(initialStock),
    expenses: List<ExpenseRecord>.unmodifiable(expenses),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'startDate': startDate,
    'currentStaffId': currentStaffId,
    'shop': shop.toJson(),
    'packages': packages.map((x) => x.toJson()).toList(),
    'addons': addons.map((x) => x.toJson()).toList(),
    'suppliers': suppliers.map((x) => x.toJson()).toList(),
    'ingredients': ingredients.map((x) => x.toJson()).toList(),
    'tables': tables.map((x) => x.toJson()).toList(),
    'staff': staff.map((x) => x.toJson()).toList(),
    'payments': payments.map((x) => x.toJson()).toList(),
    'expenseTypes': expenseTypes.map((x) => x.toJson()).toList(),
    'fixedCosts': fixedCosts.map((x) => x.toJson()).toList(),
    'seq': seq,
    'counts': counts,
    'sales': sales.map((x) => x.toJson()).toList(),
    'purchases': purchases.map((x) => x.toJson()).toList(),
    'shifts': shifts.map((x) => x.toJson()).toList(),
    'openTables': openTables.map((k, v) => MapEntry(k, v.toJson())),
    'initialStock': initialStock.map((k, v) => MapEntry(k, v.toJson())),
    'expenses': expenses.map((x) => x.toJson()).toList(),
  };
}
