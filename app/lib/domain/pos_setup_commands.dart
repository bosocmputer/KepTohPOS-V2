import 'package:app/domain/entities.dart';
import 'package:app/domain/setup_ops.dart';

/// Store-setup commands of the repository. They run online only and return a
/// [SetupCrudResult] carrying the validation outcome for the setup screen.
abstract interface class PosSetupCommands {
  /// Validates and saves the store profile and VAT settings.
  Future<SetupCrudResult> saveShopSettings(ShopConfig next);

  /// Saves the profit and costing formulas.
  Future<SetupCrudResult> saveCostingSettings(ShopConfig next);

  /// Validates and saves a package.
  Future<SetupCrudResult> savePackage(PackageItem item);

  /// Validates and saves an addon.
  Future<SetupCrudResult> saveAddon(AddonItem item);

  /// Validates and saves an ingredient.
  Future<SetupCrudResult> saveIngredient(IngredientItem item);

  /// Validates and saves a supplier.
  Future<SetupCrudResult> saveSupplier(SupplierItem item);

  /// Validates and saves a dining table.
  Future<SetupCrudResult> saveDiningTable(DiningTable item);

  /// Validates and saves a staff member; [actorRole] is who is making the edit.
  Future<SetupCrudResult> saveStaffMember(
    StaffMember item, {
    String? actorRole,
  });

  /// Validates and saves a payment method.
  Future<SetupCrudResult> savePaymentMethod(PaymentMethod item);

  /// Validates and saves a bank account.
  Future<SetupCrudResult> saveBankAccount(BankAccountItem item);

  /// Validates and saves a monthly fixed cost.
  Future<SetupCrudResult> saveFixedCost(FixedCostItem item);

  /// Validates and saves an expense type.
  Future<SetupCrudResult> saveExpenseType(ExpenseType item);

  /// Deletes an item by [id] from [section] unless a guard blocks it.
  Future<SetupCrudResult> deleteSetupItem({
    required String section,
    required String id,
    String? currentStaffId,
  });

  /// Replaces transactions with 30 days of demo data.
  Future<SetupCrudResult> resetDemoData(DateTime now);

  /// Clears daily transactions while keeping the catalog.
  Future<SetupCrudResult> clearDailyData(DateTime now);

  /// Advances the simulated calendar by one day.
  Future<SetupCrudResult> advanceSimulationDay();
}
