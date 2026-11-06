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

  SetupCrudResult _runMutation(SetupCrudResult Function(PosState s) mutator) {
    emit(
      state.copyWith(
        status: SetupStatus.saving,
        errorMessage: '',
        guardModalMessage: '',
      ),
    );
    late SetupCrudResult res;
    _repository.update((s) => res = mutator(s));
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
  SetupCrudResult saveShop(ShopConfig next) => _runMutation((s) {
    if (next.name.trim().isEmpty) {
      return const SetupCrudResult.failure('กรุณากรอกชื่อร้าน');
    }
    s.shop = next;
    return const SetupCrudResult.success('บันทึกข้อมูลร้านแล้ว');
  });

  /// Saves profit & costing calculation formulas (`CostingForm`).
  SetupCrudResult saveCosting(ShopConfig next) => _runMutation((s) {
    s.shop = next;
    return const SetupCrudResult.success('บันทึกสูตรคำนวณแล้ว');
  });

  /// Validates and saves a buffet [PackageItem].
  SetupCrudResult upsertPackage(PackageItem item) =>
      _runMutation((s) => upsertPackageInState(s, item));

  /// Toggles active status on a [PackageItem].
  SetupCrudResult togglePackageActive(PackageItem x, {required bool active}) =>
      upsertPackage(x.copyWith(active: active));

  /// Validates and saves an [AddonItem].
  SetupCrudResult upsertAddon(AddonItem item) =>
      _runMutation((s) => upsertAddonInState(s, item));

  /// Toggles active status on an [AddonItem].
  SetupCrudResult toggleAddonActive(AddonItem item, {required bool active}) =>
      upsertAddon(item.copyWith(active: active));

  /// Validates and saves an [IngredientItem].
  SetupCrudResult upsertIngredient(IngredientItem item) =>
      _runMutation((s) => upsertIngredientInState(s, item));

  /// Validates and saves a [SupplierItem].
  SetupCrudResult upsertSupplier(SupplierItem item) =>
      _runMutation((s) => upsertSupplierInState(s, item));

  /// Validates and saves a [DiningTable].
  SetupCrudResult upsertTable(DiningTable item) =>
      _runMutation((s) => upsertTableInState(s, item));

  /// Validates and saves a [StaffMember] with PIN and active-owner guards.
  SetupCrudResult upsertStaff(StaffMember item, {String? actorRole}) =>
      _runMutation((s) => upsertStaffInState(s, item, actorRole: actorRole));

  /// Toggles active status on a [StaffMember] with active-owner protection.
  SetupCrudResult toggleStaffActive(
    StaffMember item, {
    required bool active,
    String? actorRole,
  }) => upsertStaff(item.copyWith(active: active), actorRole: actorRole);

  /// Validates and saves a [PaymentMethod].
  SetupCrudResult upsertPayment(PaymentMethod item) =>
      _runMutation((s) => upsertPaymentInState(s, item));

  /// Toggles active status on a [PaymentMethod].
  SetupCrudResult togglePaymentActive(
    PaymentMethod x, {
    required bool active,
  }) => upsertPayment(x.copyWith(active: active));

  /// Validates and saves a [FixedCostItem].
  SetupCrudResult upsertFixedCost(FixedCostItem item) =>
      _runMutation((s) => upsertFixedCostInState(s, item));

  /// Toggles active status on a [FixedCostItem].
  SetupCrudResult toggleFixedCostActive(
    FixedCostItem item, {
    required bool active,
  }) => upsertFixedCost(item.copyWith(active: active));

  /// Validates and saves an [ExpenseType].
  SetupCrudResult upsertExpenseType(ExpenseType item) =>
      _runMutation((s) => upsertExpenseTypeInState(s, item));

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
  SetupCrudResult deleteItem({
    required String section,
    required String id,
    String? currentStaffId,
  }) => _runMutation(
    (s) => deleteFromSetupSection(
      s,
      section: section,
      id: id,
      currentStaffId: currentStaffId,
    ),
  );

  /// Resets 30-day demo transactions while preserving catalog setup.
  void resetDemoTransactions() => _runMutation((s) {
    resetDemoTransactionsInState(s, now: _clock());
    return const SetupCrudResult.success(
      'รีเซ็ตข้อมูลตัวอย่าง 30 วันเรียบร้อย',
    );
  });

  /// Clears all daily transactions to zero while keeping master catalogs.
  SetupCrudResult clearDailyTransactions() =>
      _runMutation((s) => clearDailyTransactionsInState(s, now: _clock()));

  /// Advances the simulated calendar by 1 day (shifts recorded history -1 day).
  SetupCrudResult advanceSimulationDay() =>
      _runMutation(advanceSimulationDayInState);

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
