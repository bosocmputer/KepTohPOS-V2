import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_setup_commands.dart';
import 'package:app/domain/setup_shop_ops.dart';

/// In-memory implementation of [PosSetupCommands].
mixin MockPosSetupCommands implements PosSetupCommands {
  /// Applies [mutator] to a copy of the state and broadcasts the result.
  PosState update(void Function(PosState s) mutator);

  Future<SetupCrudResult> _run(
    SetupCrudResult Function(PosState s) mutator,
  ) async {
    late SetupCrudResult result;
    update((s) => result = mutator(s));
    return result;
  }

  @override
  Future<SetupCrudResult> saveShopSettings(ShopConfig next) =>
      _run((s) => saveShopInState(s, next));

  @override
  Future<SetupCrudResult> saveCostingSettings(ShopConfig next) =>
      _run((s) => saveCostingInState(s, next));

  @override
  Future<SetupCrudResult> savePackage(PackageItem item) =>
      _run((s) => upsertPackageInState(s, item));

  @override
  Future<SetupCrudResult> saveAddon(AddonItem item) =>
      _run((s) => upsertAddonInState(s, item));

  @override
  Future<SetupCrudResult> saveIngredient(IngredientItem item) =>
      _run((s) => upsertIngredientInState(s, item));

  @override
  Future<SetupCrudResult> saveSupplier(SupplierItem item) =>
      _run((s) => upsertSupplierInState(s, item));

  @override
  Future<SetupCrudResult> saveDiningTable(DiningTable item) =>
      _run((s) => upsertTableInState(s, item));

  @override
  Future<SetupCrudResult> saveStaffMember(
    StaffMember item, {
    String? actorRole,
  }) => _run((s) => upsertStaffInState(s, item, actorRole: actorRole));

  @override
  Future<SetupCrudResult> savePaymentMethod(PaymentMethod item) =>
      _run((s) => upsertPaymentInState(s, item));

  @override
  Future<SetupCrudResult> saveBankAccount(BankAccountItem item) =>
      _run((s) => upsertBankAccountInState(s, item));

  @override
  Future<SetupCrudResult> saveFixedCost(FixedCostItem item) =>
      _run((s) => upsertFixedCostInState(s, item));

  @override
  Future<SetupCrudResult> saveExpenseType(ExpenseType item) =>
      _run((s) => upsertExpenseTypeInState(s, item));

  @override
  Future<SetupCrudResult> deleteSetupItem({
    required String section,
    required String id,
    String? currentStaffId,
  }) => _run(
    (s) => deleteFromSetupSection(
      s,
      section: section,
      id: id,
      currentStaffId: currentStaffId,
    ),
  );

  @override
  Future<SetupCrudResult> resetDemoData(DateTime now) => _run((s) {
    resetDemoTransactionsInState(s, now: now);
    return const SetupCrudResult.success(
      'รีเซ็ตข้อมูลตัวอย่าง 30 วันเรียบร้อย',
    );
  });

  @override
  Future<SetupCrudResult> clearDailyData(DateTime now) =>
      _run((s) => clearDailyTransactionsInState(s, now: now));

  @override
  Future<SetupCrudResult> advanceSimulationDay() =>
      _run(advanceSimulationDayInState);
}
