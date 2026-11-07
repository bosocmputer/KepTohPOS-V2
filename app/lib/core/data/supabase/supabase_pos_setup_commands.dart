import 'package:app/core/data/supabase/supabase_pos_base.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/setup_shop_ops.dart';

const SetupCrudResult _kNeedsOwner = SetupCrudResult.failure(
  'กรุณาเข้าสู่ระบบบัญชีเจ้าของร้านก่อนแก้ไขข้อมูลร้าน',
  guard: true,
);
const SetupCrudResult _kDemoOnly = SetupCrudResult.failure(
  'เมนูนี้ใช้ได้เฉพาะข้อมูลตัวอย่าง',
  guard: true,
);

/// Setup changes: validated by the domain on a copy of the state, then written
/// with the owner's login under row-level security.
mixin SupabasePosSetupCommands on SupabasePosBase implements PosRepository {
  Future<SetupCrudResult> _save(
    SetupCrudResult Function(PosState copy) validate,
    Future<void> Function() write,
  ) async {
    if (!hasOwnerSession) return _kNeedsOwner;
    final result = validate(posState.copy());
    if (!result.ok) return result;
    try {
      await write();
      await reload();
      return result;
    } on Object catch (e) {
      return SetupCrudResult.failure(describeError(e).message);
    }
  }

  Future<void> _upsert(String table, Map<String, dynamic> row) => ownerClient!
      .from(table)
      .upsert(<String, dynamic>{...row, 'shop_id': shopId}, onConflict: 'id');

  /// Inserts a new row or updates an existing one, never an upsert: for
  /// `ON CONFLICT DO UPDATE` Postgres needs read access to every updated
  /// column, and cost columns are unreadable so devices never see them.
  Future<void> _insertOrUpdate(
    String table, {
    required String id,
    required bool exists,
    required Map<String, dynamic> row,
  }) async {
    if (exists) {
      await ownerClient!
          .from(table)
          .update(row)
          .eq('id', id)
          .eq('shop_id', shopId);
    } else {
      await ownerClient!.from(table).insert(<String, dynamic>{
        ...row,
        'id': id,
        'shop_id': shopId,
      });
    }
  }

  Map<String, dynamic> _shopRow(ShopConfig s) => <String, dynamic>{
    'name': s.name,
    'branch_name': s.branch,
    'address': s.address,
    'phone': s.phone,
    'promptpay': s.promptpay,
    'vat_mode': s.vatMode,
    'vat_rate': s.vatRate,
    'service_pct': s.servicePct,
    'default_float': s.defaultFloat,
    'receipt_footer': s.receiptFooter,
    'use_timer': s.useTimer,
    'pay_timing': s.payTiming,
    'cost_method': s.costMethod,
    'show_net_profit': s.showNetProfit,
    'child_head_weight': s.childHeadWeight,
    'open_days_per_month': s.openDaysPerMonth,
    'fixed_cost_divisor': s.fixedCostDivisor,
    'weekly_count_dow': s.weeklyCountDow,
    'day_cutoff_minutes': s.dayCutoffMinutes,
    'rounding': s.rounding,
  };

  @override
  Future<SetupCrudResult> saveShopSettings(ShopConfig next) => _save(
    (s) => saveShopInState(s, next),
    () async {
      final tax = next.taxId.replaceAll(RegExp(r'[\s-]'), '');
      await ownerClient!.from('shops').update(_shopRow(next)).eq('id', shopId);
      await ownerClient!
          .from('organizations')
          .update(<String, dynamic>{'tax_id': tax.isEmpty ? null : tax})
          .eq('id', organizationId);
    },
  );

  @override
  Future<SetupCrudResult> saveCostingSettings(ShopConfig next) => _save(
    (s) => saveCostingInState(s, next),
    () => ownerClient!.from('shops').update(_shopRow(next)).eq('id', shopId),
  );

  @override
  Future<SetupCrudResult> savePackage(PackageItem i) => _save(
    (s) => upsertPackageInState(s, i),
    () => _upsert('packages', <String, dynamic>{
      'id': serverId(i.id),
      'name': i.name,
      'adult_price': i.adultPrice,
      'child_price': i.childPrice,
      'child_rule': i.childRule,
      'free_rule': i.freeRule,
      'time_limit_min': i.timeLimit,
      'active': i.active,
    }),
  );

  @override
  Future<SetupCrudResult> saveAddon(AddonItem i) => _save(
    (s) => upsertAddonInState(s, i),
    () => _insertOrUpdate(
      'addons',
      id: serverId(i.id),
      exists: posState.addons.any((x) => x.id == i.id),
      row: <String, dynamic>{
        'name': i.name,
        'category': i.category,
        'price': i.price,
        'cost': i.cost,
        'stock': i.stock,
        'active': i.active,
      },
    ),
  );

  @override
  Future<SetupCrudResult> saveIngredient(IngredientItem i) => _save(
    (s) => upsertIngredientInState(s, i),
    () => _insertOrUpdate(
      'ingredients',
      id: serverId(i.id),
      exists: posState.ingredients.any((x) => x.id == i.id),
      row: <String, dynamic>{
        'name': i.name,
        'unit': i.unit,
        'last_cost': i.lastCost,
        'par': i.par,
        'supplier_id': i.supplierId.isEmpty ? null : i.supplierId,
        'category': i.category,
        'use_per_head': i.use,
        'location': i.location,
        'count_freq': i.countFreq,
      },
    ),
  );

  @override
  Future<SetupCrudResult> saveSupplier(SupplierItem i) => _save(
    (s) => upsertSupplierInState(s, i),
    () => _upsert('suppliers', <String, dynamic>{
      'id': serverId(i.id),
      'name': i.name,
      'phone': i.phone,
      'note': i.note,
    }),
  );

  @override
  Future<SetupCrudResult> saveDiningTable(DiningTable i) => _save(
    (s) => upsertTableInState(s, i),
    () => _upsert('dining_tables', <String, dynamic>{
      'id': serverId(i.id),
      'name': i.name,
      'seats': i.seats,
      'zone': i.zone,
    }),
  );

  /// An empty PIN on an existing staff member keeps the current one: PINs are
  /// hashed on the server, so the form can never show or compare them.
  @override
  Future<SetupCrudResult> saveStaffMember(StaffMember i, {String? actorRole}) {
    final isExisting = posState.staff.any((x) => x.id == i.id);
    final keepPin = isExisting && i.pin.isEmpty;
    final id = serverId(i.id);
    return _save(
      (s) => upsertStaffInState(
        s,
        keepPin ? i.copyWith(pin: '0000') : i,
        actorRole: actorRole,
      ),
      () async {
        await _upsert('staff', <String, dynamic>{
          'id': id,
          'name': i.name,
          'role': i.role,
          'active': i.active,
        });
        if (!keepPin) {
          await ownerClient!.rpc<void>(
            'set_staff_pin',
            params: <String, dynamic>{'p_staff_id': id, 'p_pin': i.pin},
          );
        }
      },
    );
  }

  @override
  Future<SetupCrudResult> savePaymentMethod(PaymentMethod i) => _save(
    (s) => upsertPaymentInState(s, i),
    () => _upsert('payment_methods', <String, dynamic>{
      'id': serverId(i.id),
      'name': i.name,
      'type': i.type,
      'active': i.active,
    }),
  );

  @override
  Future<SetupCrudResult> saveBankAccount(BankAccountItem i) => _save(
    (s) => upsertBankAccountInState(s, i),
    () => _upsert('bank_accounts', <String, dynamic>{
      'id': serverId(i.id),
      'bank_name': i.bankName,
      'account_no': i.accountNo,
      'account_name': i.accountName,
      'active': i.active,
    }),
  );

  @override
  Future<SetupCrudResult> saveFixedCost(FixedCostItem i) => _save(
    (s) => upsertFixedCostInState(s, i),
    () => _upsert('fixed_costs', <String, dynamic>{
      'id': serverId(i.id),
      'name': i.name,
      'amount': i.amount,
      'active': i.active,
    }),
  );

  @override
  Future<SetupCrudResult> saveExpenseType(ExpenseType i) => _save(
    (s) => upsertExpenseTypeInState(s, i),
    () => _upsert('expense_types', <String, dynamic>{
      'id': serverId(i.id),
      'name': i.name,
    }),
  );

  static const Map<String, String> _tableBySection = <String, String>{
    'packages': 'packages',
    'addons': 'addons',
    'ingredients': 'ingredients',
    'suppliers': 'suppliers',
    'tables': 'dining_tables',
    'staff': 'staff',
    'payments': 'payment_methods',
    'bankAccounts': 'bank_accounts',
    'fixedCosts': 'fixed_costs',
    'expenseTypes': 'expense_types',
  };

  @override
  Future<SetupCrudResult> deleteSetupItem({
    required String section,
    required String id,
    String? currentStaffId,
  }) => _save(
    (s) => deleteFromSetupSection(
      s,
      section: section,
      id: id,
      currentStaffId: currentStaffId,
    ),
    () => ownerClient!.from(_tableBySection[section]!).delete().eq('id', id),
  );

  @override
  Future<SetupCrudResult> resetDemoData(DateTime now) async => _kDemoOnly;

  @override
  Future<SetupCrudResult> clearDailyData(DateTime now) async => _kDemoOnly;

  @override
  Future<SetupCrudResult> advanceSimulationDay() async => _kDemoOnly;
}
