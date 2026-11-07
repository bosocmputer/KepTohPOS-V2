import 'dart:async';

import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/cubit/setup_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/setup/presentation/cubit/setup_state.dart';

/// Cubit managing store configuration, catalog CRUD, relational delete guards,
/// and JSON export/import/reset (`SetupView` in `prototype/index.html`).
class SetupCubit extends Cubit<SetupState> {
  new(
    PosRepository repository, {
    String initialTab = 'shop',
    DateTime? now,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock ?? (() => now ?? DateTime.now()),
       super(SetupState(posState: repository.state, activeTab: initialTab)) {
    _sub = _repository.stream.listen((s) {
      if (!isClosed) {
        emit(state.copyWith(posState: s));
      }
    });
  }

  final PosRepository _repository;
  final DateTime Function() _clock;
  StreamSubscription<PosState>? _sub;

  /// Switches the active setup navigation section.
  void setTab(String tab) {
    if (tab.isEmpty || tab == state.activeTab) return;
    emit(
      state.copyWith(
        activeTab: tab,
        searchQuery: '',
        errorMessage: '',
        guardModalMessage: '',
      ),
    );
  }

  /// Updates the search filter query in the current catalog panel.
  void setSearchQuery(String query) {
    if (query != state.searchQuery) emit(state.copyWith(searchQuery: query));
  }

  /// Clears the transient toast notification message.
  void clearToast() {
    if (state.toastMessage.isNotEmpty) emit(state.copyWith(toastMessage: ''));
  }

  /// Clears the active guard warning modal message.
  void clearGuardModal() {
    if (state.guardModalMessage.isNotEmpty) {
      emit(state.copyWith(guardModalMessage: ''));
    }
  }

  /// Clears the active validation error message.
  void clearError() {
    if (state.errorMessage.isNotEmpty) emit(state.copyWith(errorMessage: ''));
  }

  Future<SetupCrudResult> _run(Future<SetupCrudResult> command) async {
    emit(
      state.copyWith(
        status: SetupStatus.saving,
        errorMessage: '',
        guardModalMessage: '',
      ),
    );
    final res = await command;
    emit(
      state.copyWith(
        posState: _repository.state,
        status: res.ok ? SetupStatus.ready : SetupStatus.error,
        toastMessage: res.ok ? res.message : state.toastMessage,
        errorMessage: !res.ok && !res.isGuardBlock ? res.message : '',
        guardModalMessage: !res.ok && res.isGuardBlock ? res.message : '',
      ),
    );
    return res;
  }

  /// Saves general store profile and VAT settings (`ShopForm`).
  Future<SetupCrudResult> saveShop(ShopConfig next) =>
      _run(_repository.saveShopSettings(next));

  /// Saves profit & costing calculation formulas (`CostingForm`).
  Future<SetupCrudResult> saveCosting(ShopConfig next) =>
      _run(_repository.saveCostingSettings(next));

  /// Validates and saves a [PackageItem].
  Future<SetupCrudResult> upsertPackage(PackageItem item) =>
      _run(_repository.savePackage(item));

  /// Toggles active status on a [PackageItem].
  Future<SetupCrudResult> togglePackageActive(
    PackageItem x, {
    required bool active,
  }) => upsertPackage(x.copyWith(active: active));

  /// Validates and saves an [AddonItem].
  Future<SetupCrudResult> upsertAddon(AddonItem item) =>
      _run(_repository.saveAddon(item));

  /// Toggles active status on an [AddonItem].
  Future<SetupCrudResult> toggleAddonActive(
    AddonItem item, {
    required bool active,
  }) => upsertAddon(item.copyWith(active: active));

  /// Validates and saves an [IngredientItem].
  Future<SetupCrudResult> upsertIngredient(IngredientItem item) =>
      _run(_repository.saveIngredient(item));

  /// Validates and saves a [SupplierItem].
  Future<SetupCrudResult> upsertSupplier(SupplierItem item) =>
      _run(_repository.saveSupplier(item));

  /// Validates and saves a [DiningTable].
  Future<SetupCrudResult> upsertTable(DiningTable item) =>
      _run(_repository.saveDiningTable(item));

  /// Validates and saves a [StaffMember] with active-owner protection.
  Future<SetupCrudResult> upsertStaff(StaffMember item, {String? actorRole}) =>
      _run(_repository.saveStaffMember(item, actorRole: actorRole));

  /// Toggles active status on a [StaffMember] with active-owner protection.
  Future<SetupCrudResult> toggleStaffActive(
    StaffMember item, {
    required bool active,
    String? actorRole,
  }) => upsertStaff(item.copyWith(active: active), actorRole: actorRole);

  /// Validates and saves a [PaymentMethod].
  Future<SetupCrudResult> upsertPayment(PaymentMethod item) =>
      _run(_repository.savePaymentMethod(item));

  /// Toggles active status on a [PaymentMethod].
  Future<SetupCrudResult> togglePaymentActive(
    PaymentMethod item, {
    required bool active,
  }) => upsertPayment(item.copyWith(active: active));

  /// Validates and saves a [BankAccountItem].
  Future<SetupCrudResult> upsertBankAccount(BankAccountItem item) =>
      _run(_repository.saveBankAccount(item));

  /// Toggles active status on a [BankAccountItem].
  Future<SetupCrudResult> toggleBankAccountActive(
    BankAccountItem x, {
    required bool active,
  }) => upsertBankAccount(x.copyWith(active: active));

  /// Validates and saves a [FixedCostItem].
  Future<SetupCrudResult> upsertFixedCost(FixedCostItem item) =>
      _run(_repository.saveFixedCost(item));

  /// Toggles active status on a [FixedCostItem].
  Future<SetupCrudResult> toggleFixedCostActive(
    FixedCostItem item, {
    required bool active,
  }) => upsertFixedCost(item.copyWith(active: active));

  /// Validates and saves an [ExpenseType].
  Future<SetupCrudResult> upsertExpenseType(ExpenseType item) =>
      _run(_repository.saveExpenseType(item));

  /// Checks whether deleting [id] in [section] is blocked before showing
  /// confirmation. If blocked, emits `guardModalMessage` and returns `false`.
  bool checkCanDelete({
    required String section,
    required String id,
    String? currentStaffId,
  }) {
    final guard = checkSetupDeleteGuard(
      state.posState,
      section: section,
      id: id,
      currentStaffId: currentStaffId,
    );
    if (guard != null) {
      emit(state.copyWith(guardModalMessage: guard));
      return false;
    }
    return true;
  }

  /// Deletes an item by [id] from [section] after confirmation.
  Future<SetupCrudResult> deleteItem({
    required String section,
    required String id,
    String? currentStaffId,
  }) => _run(
    _repository.deleteSetupItem(
      section: section,
      id: id,
      currentStaffId: currentStaffId,
    ),
  );

  /// Resets 30-day demo transactions while preserving catalog setup.
  Future<SetupCrudResult> resetDemoTransactions() =>
      _run(_repository.resetDemoData(_clock()));

  /// Clears all daily transactions to zero while keeping master catalogs.
  Future<SetupCrudResult> clearDailyTransactions() =>
      _run(_repository.clearDailyData(_clock()));

  /// Advances the simulated calendar by 1 day (shifts recorded history -1 day).
  Future<SetupCrudResult> advanceSimulationDay() =>
      _run(_repository.advanceSimulationDay());

  /// Whether setup changes can be saved right now.
  bool get canEditSetup => _repository.canEditSetup;

  /// Whether export, import and the simulation tools are available.
  bool get isDemoData => _repository.isDemoData;

  /// Exports the entire [PosState] as formatted JSON.
  String exportJson() => _repository.exportStateJson();

  /// Imports a full [PosState] JSON snapshot into the repository.
  bool importJson(String rawJson) {
    try {
      emit(state.copyWith(status: SetupStatus.saving, errorMessage: ''));
      final next = _repository.importStateJson(rawJson);
      emit(
        state.copyWith(
          posState: next,
          status: SetupStatus.ready,
          toastMessage: 'นำเข้าข้อมูล JSON เรียบร้อย',
        ),
      );
      return true;
    } on Object {
      emit(
        state.copyWith(
          status: SetupStatus.error,
          guardModalMessage: 'รูปแบบไฟล์ JSON ไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง',
        ),
      );
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
