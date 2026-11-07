import 'dart:async';

import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:app/features/stock/presentation/cubit/stock_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/stock/presentation/cubit/stock_state.dart';

/// Cubit managing `/stock` tabs, purchases, daily expenses, and stock balance
/// (`StockView` in `prototype/index.html:1420-1509`).
class StockCubit extends Cubit<StockState> {
  new(
    this._repository, {
    DateTime? now,
    DateTime Function()? clock,
    String initialTab = 'count',
  }) : _clock = clock ?? (now != null ? () => now : DateTime.now),
       super(
         _initialState(
           _repository,
           (clock ?? (now != null ? () => now : DateTime.now))(),
           initialTab,
         ),
       ) {
    _sub = _repository.stream.listen(_onRepositoryUpdated);
  }

  final PosRepository _repository;
  final DateTime Function() _clock;
  StreamSubscription<PosState>? _sub;

  static StockState _initialState(
    PosRepository repo,
    DateTime now,
    String initialTab,
  ) {
    final s = repo.state;
    final today = businessDayKey(now, s.shop.dayCutoffMinutes);
    final ledger = computeLedger(s, today: today);
    return StockState(
      posState: s,
      ledger: ledger,
      todayDate: today,
      selectedDate: today,
      activeTab: initialTab,
      showCosts: repo.canReadCosts,
    );
  }

  void _onRepositoryUpdated(PosState s) {
    final today = businessDayKey(_clock(), s.shop.dayCutoffMinutes);
    final ledger = computeLedger(s, today: today);
    emit(
      state.copyWith(
        posState: s,
        ledger: ledger,
        todayDate: today,
        showCosts: _repository.canReadCosts,
      ),
    );
  }

  /// Switches the active `/stock` tab (`'count'|'purchase'|'expense'|'balance'`).
  void setTab(String tab) {
    if (tab == state.activeTab) return;
    emit(state.copyWith(activeTab: tab));
  }

  /// Changes the selected date (`YYYY-MM-DD`).
  void setDate(String date) {
    if (date.isEmpty || date == state.selectedDate) return;
    emit(state.copyWith(selectedDate: date));
  }

  /// Updates the topbar search query and resets balance pagination to page 1.
  void setSearchQuery(String query) {
    if (query == state.searchQuery) return;
    emit(state.copyWith(searchQuery: query, balancePage: 1));
  }

  /// Switches the Balance tab between `'list'` and `'grid'` view modes.
  void setBalanceViewMode(String mode) {
    if (mode == state.balanceViewMode) return;
    emit(state.copyWith(balanceViewMode: mode, balancePage: 1));
  }

  /// Opens or closes the right-side filter drawer for the Balance tab.
  void setFilterDrawerOpen({required bool open}) {
    if (open == state.filterDrawerOpen) return;
    emit(state.copyWith(filterDrawerOpen: open));
  }

  /// Toggles a storage location filter (`'fridge' | 'freezer' | 'dry'`).
  void toggleLocationFilter(String location) {
    final next = Set<String>.from(state.locationFilters);
    if (!next.remove(location)) {
      next.add(location);
    }
    emit(state.copyWith(locationFilters: next, balancePage: 1));
  }

  /// Sets the stock status filter (`'all' | 'ok' | 'low' | 'out'`).
  void setStatusFilter(String status) {
    if (status == state.statusFilter) return;
    emit(state.copyWith(statusFilter: status, balancePage: 1));
  }

  /// Clears all Balance tab filters.
  void clearFilters() {
    emit(
      state.copyWith(
        locationFilters: const <String>{},
        statusFilter: 'all',
        balancePage: 1,
      ),
    );
  }

  /// Changes the current page in the Balance tab.
  void setBalancePage(int page) {
    emit(state.copyWith(balancePage: page));
  }

  /// Runs [command], showing a failure as a toast instead of an error.
  Future<bool> _attempt(Future<bool> Function() command) async {
    try {
      return await command();
    } on PosCommandException catch (e) {
      emit(state.copyWith(toastMessage: e.message));
      return false;
    }
  }

  /// Saves a new or edited purchase bill. Editing requires
  /// `me.role != 'cashier'`.
  Future<bool> submitPurchase({
    required String date,
    required String supplierId,
    required List<PurchaseLine> lines,
    required StaffMember staff,
    String note = '',
    String? editId,
  }) async {
    final now = _clock();
    final ok = await _attempt(
      () => _repository.recordPurchase(
        date: date,
        supplierId: supplierId,
        lines: lines,
        staff: staff,
        note: note,
        editId: editId,
        now: now,
      ),
    );
    if (!ok) return false;
    final s = _repository.state;
    final today = businessDayKey(now, s.shop.dayCutoffMinutes);
    final ledger = computeLedger(s, today: today);
    emit(
      state.copyWith(
        posState: s,
        ledger: ledger,
        todayDate: today,
        toastMessage: 'บันทึกการรับของแล้ว',
      ),
    );
    return true;
  }

  /// Deletes a purchase bill. Restricted to `manager` / `owner`.
  Future<bool> removePurchase({
    required String purchaseId,
    required StaffMember staff,
  }) async {
    if (staff.role == 'cashier') return false;
    final ok = await _attempt(
      () => _repository.removePurchase(purchaseId: purchaseId, staff: staff),
    );
    if (!ok) return false;
    final s = _repository.state;
    final today = businessDayKey(_clock(), s.shop.dayCutoffMinutes);
    final ledger = computeLedger(s, today: today);
    emit(
      state.copyWith(
        posState: s,
        ledger: ledger,
        todayDate: today,
        toastMessage: 'ลบแล้ว',
      ),
    );
    return true;
  }

  /// Saves new or edited daily expenses. Editing requires
  /// `me.role != 'cashier'`.
  Future<bool> submitExpenses({
    required String date,
    required List<ExpenseDraftLine> lines,
    required StaffMember staff,
    String? editId,
  }) async {
    final now = _clock();
    final ok = await _attempt(
      () => _repository.recordExpenses(
        date: date,
        lines: lines,
        staff: staff,
        editId: editId,
        now: now,
      ),
    );
    if (!ok) return false;
    final s = _repository.state;
    final today = businessDayKey(now, s.shop.dayCutoffMinutes);
    final ledger = computeLedger(s, today: today);
    emit(
      state.copyWith(
        posState: s,
        ledger: ledger,
        todayDate: today,
        toastMessage: 'บันทึกค่าใช้จ่ายแล้ว',
      ),
    );
    return true;
  }

  /// Deletes a daily expense. Restricted to `manager` / `owner`.
  Future<bool> removeExpense({
    required String expenseId,
    required StaffMember staff,
  }) async {
    if (staff.role == 'cashier') return false;
    final ok = await _attempt(
      () => _repository.removeExpense(expenseId: expenseId, staff: staff),
    );
    if (!ok) return false;
    final s = _repository.state;
    final today = businessDayKey(_clock(), s.shop.dayCutoffMinutes);
    final ledger = computeLedger(s, today: today);
    emit(
      state.copyWith(
        posState: s,
        ledger: ledger,
        todayDate: today,
        toastMessage: 'ลบแล้ว',
      ),
    );
    return true;
  }

  /// Clears any shown toast message immediately.
  void clearToast() {
    if (state.toastMessage.isEmpty) return;
    emit(state.copyWith(toastMessage: ''));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
