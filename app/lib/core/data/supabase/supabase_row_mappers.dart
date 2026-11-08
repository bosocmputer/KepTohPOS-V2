import 'package:app/domain/models.dart';

/// A row as returned by PostgREST.
typedef Row = Map<String, dynamic>;

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
String _s(Object? v) => v?.toString() ?? '';

/// Maps a `shops` row and its organization tax id to [ShopConfig].
ShopConfig shopFromRow(Row r, String taxId, List<BankAccountItem> accounts) =>
    ShopConfig(
      name: _s(r['name']),
      branch: _s(r['branch_name']),
      address: _s(r['address']),
      phone: _s(r['phone']),
      taxId: taxId,
      promptpay: _s(r['promptpay']),
      vatMode: _s(r['vat_mode']),
      vatRate: _d(r['vat_rate']),
      servicePct: _d(r['service_pct']),
      defaultFloat: _i(r['default_float']),
      receiptFooter: _s(r['receipt_footer']),
      useTimer: r['use_timer'] as bool,
      payTiming: _s(r['pay_timing']),
      costMethod: _s(r['cost_method']),
      showNetProfit: r['show_net_profit'] as bool,
      childHeadWeight: _d(r['child_head_weight']),
      openDaysPerMonth: _i(r['open_days_per_month']),
      fixedCostDivisor: _s(r['fixed_cost_divisor']),
      weeklyCountDow: _i(r['weekly_count_dow']),
      dayCutoffMinutes: _i(r['day_cutoff_minutes']),
      rounding: _s(r['rounding']),
      themeMode: _s(r['theme_mode']),
      themePalette: _s(r['theme_palette']),
      bankAccounts: accounts,
    );

/// Maps a `bank_accounts` row.
BankAccountItem bankFromRow(Row r) => BankAccountItem(
  id: _s(r['id']),
  bankName: _s(r['bank_name']),
  accountNo: _s(r['account_no']),
  accountName: _s(r['account_name']),
  active: r['active'] as bool,
);

/// Maps a `packages` row.
PackageItem packageFromRow(Row r) => PackageItem(
  id: _s(r['id']),
  name: _s(r['name']),
  adultPrice: _i(r['adult_price']),
  childPrice: _i(r['child_price']),
  childRule: _s(r['child_rule']),
  freeRule: _s(r['free_rule']),
  timeLimit: _i(r['time_limit_min']),
  active: r['active'] as bool,
);

/// Maps an `addons` row; [cost] comes from manager-only data.
AddonItem addonFromRow(Row r, int cost) => AddonItem(
  id: _s(r['id']),
  name: _s(r['name']),
  category: _s(r['category']),
  price: _i(r['price']),
  cost: cost,
  stock: _i(r['stock']),
  active: r['active'] as bool,
);

/// Maps a `suppliers` row.
SupplierItem supplierFromRow(Row r) => SupplierItem(
  id: _s(r['id']),
  name: _s(r['name']),
  phone: _s(r['phone']),
  note: _s(r['note']),
);

/// Maps an `ingredients` row; [lastCost] comes from manager-only data.
IngredientItem ingredientFromRow(Row r, int lastCost) => IngredientItem(
  id: _s(r['id']),
  name: _s(r['name']),
  unit: _s(r['unit']),
  lastCost: lastCost,
  par: _d(r['par']),
  supplierId: _s(r['supplier_id']),
  category: _s(r['category']),
  use: _d(r['use_per_head']),
  location: _s(r['location']),
  countFreq: _s(r['count_freq']),
);

/// Maps a `dining_tables` row.
DiningTable tableFromRow(Row r) => DiningTable(
  id: _s(r['id']),
  name: _s(r['name']),
  seats: _i(r['seats']),
  zone: _s(r['zone']),
);

/// Maps a `staff` row. The PIN stays on the server, so [StaffMember.pin] is
/// always empty here.
StaffMember staffFromRow(Row r) => StaffMember(
  id: _s(r['id']),
  name: _s(r['name']),
  role: _s(r['role']),
  pin: '',
  active: r['active'] as bool,
  canViewCosts: (r['can_view_costs'] as bool?) ?? false,
);

/// Maps a `payment_methods` row.
PaymentMethod paymentFromRow(Row r) => PaymentMethod(
  id: _s(r['id']),
  name: _s(r['name']),
  type: _s(r['type']),
  active: r['active'] as bool,
);

/// Maps an `expense_types` row.
ExpenseType expenseTypeFromRow(Row r) =>
    ExpenseType(id: _s(r['id']), name: _s(r['name']));

/// Maps a `fixed_costs` row.
FixedCostItem fixedCostFromRow(Row r) => FixedCostItem(
  id: _s(r['id']),
  name: _s(r['name']),
  amount: _i(r['amount']),
  active: r['active'] as bool,
);

/// Maps a `bills` row and its lines to [BillRecord].
BillRecord billFromRow(Row r, List<OrderLineItem> lines) => BillRecord(
  id: _s(r['id']),
  no: _s(r['no']),
  date: _s(r['business_date']),
  at: _s(r['at']),
  tableId: r['table_id'] == null ? '-' : _s(r['table_id']),
  tableName: _s(r['table_name']),
  staffId: _s(r['staff_id']),
  staffName: _s(r['staff_name']),
  shiftId: r['shift_id'] as String?,
  packageId: _s(r['package_id']),
  lines: lines,
  subtotal: _i(r['subtotal']),
  service: _i(r['service']),
  vat: _i(r['vat']),
  rounding: _i(r['rounding']),
  total: _i(r['total']),
  heads: HeadsCount(
    a: _i(r['heads_a']),
    c: _i(r['heads_c']),
    f: _i(r['heads_f']),
  ),
  methodId: _s(r['method_id']),
  methodName: _s(r['method_name']),
  methodType: _s(r['method_type']),
  received: _i(r['received']),
  change: _i(r['change_amount']),
  vatMode: r['vat_mode'] as String?,
  vatRate: (r['vat_rate'] as num?)?.toDouble(),
  bankAccountId: r['bank_account_id'] as String?,
  bankAccountInfo: r['bank_account_info'] as String?,
  eatUntil: r['eat_until'] as String?,
  timeLimitMin: _i(r['time_limit_min']),
  voided: r['voided'] as bool,
  voidReason: r['void_reason'] as String?,
  voidBy: r['void_by'] as String?,
  voidAt: r['void_at'] as String?,
);

/// Maps a `bill_lines` row; [cost] comes from manager-only data.
OrderLineItem lineFromRow(Row r, int? cost) => OrderLineItem(
  type: _s(r['type']),
  id: r['item_id'] as String?,
  name: _s(r['name']),
  qty: _i(r['qty']),
  price: _i(r['price']),
  cost: cost,
);

/// Maps a `shifts` row.
ShiftRecord shiftFromRow(Row r) => ShiftRecord(
  id: _s(r['id']),
  staffId: _s(r['staff_id']),
  openedAt: _s(r['opened_at']),
  floatAmount: _i(r['float_amount']),
  closedAt: r['closed_at'] as String?,
  counted: (r['counted'] as num?)?.toInt(),
  closedBy: r['closed_by'] as String?,
);

/// Maps a `table_rounds` row.
TableRound roundFromRow(Row r) => TableRound(
  id: _s(r['id']),
  at: _s(r['at']),
  staffId: _s(r['staff_id']),
  a: _i(r['heads_a']),
  c: _i(r['heads_c']),
  f: _i(r['heads_f']),
  ad: (r['addons'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, (v as num).toInt()),
  ),
);

/// Maps a `table_adjustments` row. The domain stores reductions as negatives.
TableAdjustment adjustmentFromRow(Row r) => TableAdjustment(
  id: _s(r['id']),
  at: _s(r['at']),
  by: _s(r['by_staff_id']),
  byName: _s(r['by_name']),
  reason: _s(r['reason']),
  kind: _s(r['kind']),
  key: _s(r['key']),
  qty: -_i(r['qty']),
);

/// Maps an `expenses` row from manager-only data.
ExpenseRecord expenseFromRow(Row r) => ExpenseRecord(
  id: _s(r['id']),
  date: _s(r['business_date']),
  at: _s(r['at']),
  typeId: _s(r['type_id']),
  amount: _i(r['amount']),
  note: _s(r['note']),
);

/// Maps a `purchases` row with embedded `lines` from manager-only data.
PurchaseRecord purchaseFromRow(Row r) => PurchaseRecord(
  id: _s(r['id']),
  date: _s(r['business_date']),
  at: _s(r['at']),
  supplierId: _s(r['supplier_id']),
  note: _s(r['note']),
  lines: (r['lines'] as List<dynamic>)
      .cast<Row>()
      .map(
        (l) => PurchaseLine(
          ingId: _s(l['ingredient_id']),
          qty: _d(l['qty']),
          total: _i(l['total']),
        ),
      )
      .toList(),
);
