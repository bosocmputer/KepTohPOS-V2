import 'package:app/domain/entities.dart';
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
  });

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
}

/// Line item inside a purchase bill.
class PurchaseLine {
  const new({required this.ingId, required this.qty, required this.total});

  final String ingId;
  final double qty;
  final double total;
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

  final String id;
  final String date;
  final String at;
  final String supplierId;
  final List<PurchaseLine> lines;
  final String note;
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

  final String id;
  final String date;
  final String at;
  final String typeId;
  final double amount;
  final String note;
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
  });

  final String id;
  final String staffId;
  final String openedAt;
  final double floatAmount;
  String? closedAt;
  double? counted;
}

/// Initial stock lot (`s.initialStock[ingId]`).
class StockLot {
  const new({required this.qty, required this.cost});

  final double qty;
  final double cost;
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
}
