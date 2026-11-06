import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';

/// Lifecycle status for [SetupState].
enum SetupStatus { initial, loading, ready, saving, error }

/// Immutable state for `SetupCubit` (`SetupView` in `prototype/index.html`).
class SetupState extends Equatable {
  const new({
    required this.posState,
    this.status = SetupStatus.ready,
    this.activeTab = 'shop',
    this.searchQuery = '',
    this.toastMessage = '',
    this.errorMessage = '',
    this.guardModalMessage = '',
  });

  final PosState posState;
  final SetupStatus status;
  final String activeTab;
  final String searchQuery;
  final String toastMessage;
  final String errorMessage;
  final String guardModalMessage;

  bool get isSaving => status == SetupStatus.saving;

  String get _q => searchQuery.trim().toLowerCase();

  bool _matches(List<String> fields) {
    final q = _q;
    if (q.isEmpty) return true;
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  List<PackageItem> get filteredPackages => posState.packages
      .where((p) => _matches([p.name, p.childRule, p.freeRule]))
      .toList();

  List<AddonItem> get filteredAddons =>
      posState.addons.where((a) => _matches([a.name, a.category])).toList();

  List<IngredientItem> get filteredIngredients => posState.ingredients
      .where(
        (i) => _matches([
          i.name,
          i.category,
          i.unit,
          kLocations[i.location] ?? i.location,
          supplierNameOf(i.supplierId),
        ]),
      )
      .toList();

  List<SupplierItem> get filteredSuppliers => posState.suppliers
      .where((s) => _matches([s.name, s.phone, s.note]))
      .toList();

  List<DiningTable> get filteredTables =>
      posState.tables.where((t) => _matches([t.name, t.zone])).toList();

  List<StaffMember> get filteredStaff => posState.staff
      .where((u) => _matches([u.name, kRoles[u.role] ?? u.role]))
      .toList();

  List<PaymentMethod> get filteredPayments => posState.payments
      .where((p) => _matches([p.name, kPayTypes[p.type] ?? p.type]))
      .toList();

  List<BankAccountItem> get filteredBankAccounts => posState.shop.bankAccounts
      .where((b) => _matches([b.bankName, b.accountNo, b.accountName]))
      .toList();

  List<FixedCostItem> get filteredFixedCosts =>
      posState.fixedCosts.where((f) => _matches([f.name])).toList();

  List<ExpenseType> get filteredExpenseTypes =>
      posState.expenseTypes.where((e) => _matches([e.name])).toList();

  String supplierNameOf(String supplierId) {
    for (final s in posState.suppliers) {
      if (s.id == supplierId) return s.name;
    }
    return '-';
  }

  /// Sum of active monthly fixed costs.
  double get totalMonthlyFixedCost => posState.fixedCosts
      .where((f) => f.active)
      .fold<double>(0, (sum, f) => sum + f.amount);

  /// Effective divisor for monthly fixed cost (current month's calendar days
  /// when `fixedCostDivisor == 'calendar'`, or `openDaysPerMonth`).
  int get effectiveFixedCostDivisor {
    if (posState.shop.fixedCostDivisor == 'calendar') {
      final now = DateTime.now();
      return DateTime(now.year, now.month + 1, 0).day;
    }
    return posState.shop.openDaysPerMonth <= 0
        ? 30
        : posState.shop.openDaysPerMonth;
  }

  /// Average daily fixed cost (`totalMonthlyFixedCost / effectiveFixedCostDivisor`).
  double get dailyFixedCost =>
      totalMonthlyFixedCost / effectiveFixedCostDivisor;

  /// Item count for a given catalog tab ID (`null` for form-only tabs).
  int? itemCountOf(String tabId) => switch (tabId) {
    'packages' => posState.packages.length,
    'addons' => posState.addons.length,
    'ingredients' => posState.ingredients.length,
    'suppliers' => posState.suppliers.length,
    'tables' => posState.tables.length,
    'staff' => posState.staff.length,
    'payments' => posState.payments.length,
    'fixedCosts' => posState.fixedCosts.length,
    'expenseTypes' => posState.expenseTypes.length,
    _ => null,
  };

  SetupState copyWith({
    PosState? posState,
    SetupStatus? status,
    String? activeTab,
    String? searchQuery,
    String? toastMessage,
    String? errorMessage,
    String? guardModalMessage,
  }) => SetupState(
    posState: posState ?? this.posState,
    status: status ?? this.status,
    activeTab: activeTab ?? this.activeTab,
    searchQuery: searchQuery ?? this.searchQuery,
    toastMessage: toastMessage ?? this.toastMessage,
    errorMessage: errorMessage ?? this.errorMessage,
    guardModalMessage: guardModalMessage ?? this.guardModalMessage,
  );

  @override
  List<Object?> get props => [
    posState,
    status,
    activeTab,
    searchQuery,
    toastMessage,
    errorMessage,
    guardModalMessage,
  ];
}
