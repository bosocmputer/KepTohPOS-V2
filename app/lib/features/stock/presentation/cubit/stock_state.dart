import 'dart:math' as math;

import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';

/// Immutable state for `StockCubit` covering tabs, purchases, daily expenses,
/// and stock balance (`StockView` in `prototype/index.html:1420-1509`).
class StockState extends Equatable {
  const new({
    required this.posState,
    required this.ledger,
    required this.todayDate,
    required this.selectedDate,
    this.activeTab = 'count',
    this.searchQuery = '',
    this.balanceViewMode = 'list',
    this.filterDrawerOpen = false,
    this.locationFilters = const <String>{},
    this.statusFilter = 'all',
    this.balancePage = 1,
    this.toastMessage = '',
  });

  final PosState posState;
  final LedgerResult ledger;
  final String todayDate;
  final String selectedDate;
  final String activeTab;
  final String searchQuery;
  final String balanceViewMode;
  final bool filterDrawerOpen;
  final Set<String> locationFilters;
  final String statusFilter;
  final int balancePage;
  final String toastMessage;

  /// All selectable dates from `startDate` through `todayDate` (newest first).
  List<String> get availableDates {
    final dates = <String>[];
    for (
      var d = parseKey(posState.startDate);
      dkey(d).compareTo(todayDate) <= 0;
      d = addDays(d, 1)
    ) {
      dates.add(dkey(d));
    }
    return dates.reversed.toList();
  }

  /// Purchases recorded on [selectedDate] sorted chronologically.
  List<PurchaseRecord> get dayPurchases =>
      posState.purchases.where((p) => p.date == selectedDate).toList()
        ..sort((a, b) => a.at.compareTo(b.at));

  /// Total purchase spend on [selectedDate].
  double get dayPurchasesTotal => dayPurchases.fold<double>(
    0,
    (sum, p) => sum + p.lines.fold<double>(0, (s, l) => s + l.total),
  );

  /// Latest purchase for [supplierId].
  PurchaseRecord? lastPurchaseOf(String supplierId, {String? excludeId}) =>
      lastPurchaseForSupplier(posState, supplierId, excludeId: excludeId);

  /// Supplier display name for [supplierId].
  String supplierNameOf(String supplierId) =>
      posState.suppliers
          .where((x) => x.id == supplierId)
          .map((x) => x.name)
          .firstOrNull ??
      '-';

  /// Ingredient lookup by [ingId].
  IngredientItem? ingredientOf(String ingId) =>
      posState.ingredients.where((x) => x.id == ingId).firstOrNull;

  /// Daily expenses recorded on [selectedDate] sorted chronologically.
  List<ExpenseRecord> get dayExpenses =>
      posState.expenses.where((e) => e.date == selectedDate).toList()
        ..sort((a, b) => a.at.compareTo(b.at));

  /// Total daily expense amount on [selectedDate].
  double get dayExpensesTotal =>
      dayExpenses.fold<double>(0, (sum, e) => sum + e.amount);

  /// Expense type display name for [typeId].
  String expenseTypeNameOf(String typeId) =>
      posState.expenseTypes
          .where((x) => x.id == typeId)
          .map((x) => x.name)
          .firstOrNull ??
      '-';

  /// Latest date strictly before [selectedDate] that has recorded expenses.
  String? get prevExpenseDate => previousExpenseDate(posState, selectedDate);

  /// Expenses from [prevExpenseDate] for 1-tap copy (`เหมือนครั้งก่อน`).
  List<ExpenseRecord> get prevDateExpenses {
    final prev = prevExpenseDate;
    if (prev == null) return const <ExpenseRecord>[];
    return posState.expenses.where((e) => e.date == prev).toList();
  }

  /// Dynamic unit cost column header based on `shop.costMethod`.
  String get costColumnLabel =>
      posState.shop.costMethod == 'last' ? 'ราคาซื้อล่าสุด' : 'ต้นทุนเฉลี่ย';

  /// All computed [StockBalanceRow]s before search/filter.
  List<StockBalanceRow> get allBalanceRows =>
      computeStockBalanceRows(posState, ledger);

  /// Filtered & searched [StockBalanceRow]s for the Balance tab.
  List<StockBalanceRow> get filteredBalanceRows {
    final q = searchQuery.trim().toLowerCase();
    return allBalanceRows.where((r) {
      if (locationFilters.isNotEmpty) {
        final normLoc = kLocations.containsKey(r.ing.location)
            ? r.ing.location
            : 'dry';
        if (!locationFilters.contains(normLoc)) return false;
      }
      if (statusFilter != 'all' && r.status.name != statusFilter) {
        return false;
      }
      if (q.isNotEmpty) {
        final locLabel = (kLocations[r.ing.location] ?? '').toLowerCase();
        final match =
            r.ing.name.toLowerCase().contains(q) ||
            r.supplierName.toLowerCase().contains(q) ||
            locLabel.contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  /// Page size for the Balance tab (`10` in list view, `12` in grid view).
  int get balancePageSize => balanceViewMode == 'grid' ? 12 : 10;

  /// Total pages for [filteredBalanceRows].
  int get balanceTotalPages =>
      math.max(1, (filteredBalanceRows.length / balancePageSize).ceil());

  /// Clamped current page index (`1..balanceTotalPages`).
  int get effectiveBalancePage => balancePage.clamp(1, balanceTotalPages);

  /// Current page slice of [filteredBalanceRows].
  List<StockBalanceRow> get pagedBalanceRows {
    final rows = filteredBalanceRows;
    final size = balancePageSize;
    final start = (effectiveBalancePage - 1) * size;
    if (start >= rows.length) return const <StockBalanceRow>[];
    return rows.sublist(start, math.min(start + size, rows.length));
  }

  /// Total remaining stock valuation across [filteredBalanceRows].
  double get totalBalanceValue =>
      filteredBalanceRows.fold<double>(0, (sum, r) => sum + r.val);

  /// Number of active filter dimensions in the Balance filter drawer.
  int get activeFilterCount =>
      (locationFilters.isNotEmpty ? 1 : 0) + (statusFilter != 'all' ? 1 : 0);

  StockState copyWith({
    PosState? posState,
    LedgerResult? ledger,
    String? todayDate,
    String? selectedDate,
    String? activeTab,
    String? searchQuery,
    String? balanceViewMode,
    bool? filterDrawerOpen,
    Set<String>? locationFilters,
    String? statusFilter,
    int? balancePage,
    String? toastMessage,
  }) => StockState(
    posState: posState ?? this.posState,
    ledger: ledger ?? this.ledger,
    todayDate: todayDate ?? this.todayDate,
    selectedDate: selectedDate ?? this.selectedDate,
    activeTab: activeTab ?? this.activeTab,
    searchQuery: searchQuery ?? this.searchQuery,
    balanceViewMode: balanceViewMode ?? this.balanceViewMode,
    filterDrawerOpen: filterDrawerOpen ?? this.filterDrawerOpen,
    locationFilters: locationFilters ?? this.locationFilters,
    statusFilter: statusFilter ?? this.statusFilter,
    balancePage: balancePage ?? this.balancePage,
    toastMessage: toastMessage ?? this.toastMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    posState,
    ledger,
    todayDate,
    selectedDate,
    activeTab,
    searchQuery,
    balanceViewMode,
    filterDrawerOpen,
    locationFilters,
    statusFilter,
    balancePage,
    toastMessage,
  ];
}
