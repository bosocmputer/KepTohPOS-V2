import 'dart:async';

import 'package:app/domain/domain.dart';
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
    final today = dkey(now);
    final ledger = computeLedger(s, today: today);
    return StockState(
      posState: s,
      ledger: ledger,
      todayDate: today,
      selectedDate: today,
      activeTab: initialTab,
    );
  }

  void _onRepositoryUpdated(PosState s) {
    final today = dkey(_clock());
    final ledger = computeLedger(s, today: today);
    emit(state.copyWith(posState: s, ledger: ledger, todayDate: today));
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

  /// Saves a new or edited purchase bill. Editing requires
  /// `me.role != 'cashier'`.
  bool submitPurchase({
    required String date,
    required String supplierId,
    required List<PurchaseLine> lines,
    required StaffMember staff,
    String note = '',
    String? editId,
  }) {
    final now = _clock();
    var ok = false;
    _repository.update((st) {
      ok = savePurchase(
        st,
        date: date,
        supplierId: supplierId,
        lines: lines,
        me: staff,
        note: note,
        editId: editId,
        now: now,
      );
    });
    if (!ok) return false;
    final s = _repository.state;
    final today = dkey(now);
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
  bool removePurchase({
    required String purchaseId,
    required StaffMember staff,
  }) {
    if (staff.role == 'cashier') return false;
    var ok = false;
    _repository.update((st) {
      ok = deletePurchase(st, purchaseId: purchaseId, me: staff);
    });
    if (!ok) return false;
    final s = _repository.state;
    final today = dkey(_clock());
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
  bool submitExpenses({
    required String date,
    required List<ExpenseDraftLine> lines,
    required StaffMember staff,
    String? editId,
  }) {
    final now = _clock();
    var ok = false;
    _repository.update((st) {
      ok = saveExpenses(
        st,
        date: date,
        lines: lines,
        me: staff,
        editId: editId,
        now: now,
      );
    });
    if (!ok) return false;
    final s = _repository.state;
    final today = dkey(now);
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
  bool removeExpense({required String expenseId, required StaffMember staff}) {
    if (staff.role == 'cashier') return false;
    var ok = false;
    _repository.update((st) {
      ok = deleteExpense(st, expenseId: expenseId, me: staff);
    });
    if (!ok) return false;
    final s = _repository.state;
    final today = dkey(_clock());
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
