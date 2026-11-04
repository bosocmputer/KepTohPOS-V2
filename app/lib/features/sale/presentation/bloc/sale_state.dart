import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';

/// Base event for `SaleBloc` (`SaleView` in `prototype/index.html`).
sealed class SaleEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Switches the active table in `SaleView`.
final class SaleTableSelected extends SaleEvent {
  const new(this.tableId);
  final String tableId;

  @override
  List<Object?> get props => [tableId];
}

/// Selects a buffet package (`pkgId`).
final class SalePackageSelected extends SaleEvent {
  const new(this.packageId);
  final String packageId;

  @override
  List<Object?> get props => [packageId];
}

/// Changes the payment timing (`'before'` or `'after'`) when opening a table.
final class SaleTimingChanged extends SaleEvent {
  const new(this.timing);
  final String timing;

  @override
  List<Object?> get props => [timing];
}

/// Selects the active product/package tab (`cat`).
final class SaleCategorySelected extends SaleEvent {
  const new(this.category);
  final String category;

  @override
  List<Object?> get props => [category];
}

/// Updates adult (`a`), child (`c`), or free toddler (`f`) head counts.
final class SaleHeadsChanged extends SaleEvent {
  const new({this.a, this.c, this.f});
  final int? a;
  final int? c;
  final int? f;

  @override
  List<Object?> get props => [a, c, f];
}

/// Sets the quantity of an addon item in the current cart (`setDrink`).
final class SaleAddonQtyChanged extends SaleEvent {
  const new({required this.addonId, required this.qty});
  final String addonId;
  final int qty;

  @override
  List<Object?> get props => [addonId, qty];
}

/// Increments an addon item by 1 when tapping its `ProductCard`.
final class SaleAddonIncremented extends SaleEvent {
  const new(this.addonId);
  final String addonId;

  @override
  List<Object?> get props => [addonId];
}

/// Saves table notes (`NoteModal`).
final class SaleNotesSaved extends SaleEvent {
  const new(this.notes);
  final String notes;

  @override
  List<Object?> get props => [notes];
}

/// Sends the current cart as a round in eat-before-paying mode (`sendRound`).
final class SaleRoundSent extends SaleEvent {
  const new({required this.staff, this.now});
  final StaffMember staff;
  final DateTime? now;

  @override
  List<Object?> get props => [staff.id, now];
}

/// Reduces/removes an already-sent item (`adjustSent`). Manager/owner only.
final class SaleSentItemAdjusted extends SaleEvent {
  const new({
    required this.kind,
    required this.key,
    required this.qty,
    required this.reason,
    required this.staff,
    this.now,
  });

  final String kind;
  final String key;
  final int qty;
  final String reason;
  final StaffMember staff;
  final DateTime? now;

  @override
  List<Object?> get props => [kind, key, qty, reason, staff.id, now];
}

/// Closes an occupied table when `due == 0` (`เก็บโต๊ะ`).
final class SaleTableClosed extends SaleEvent {
  const new();
}

/// Clears the transient toast/error message.
final class SaleToastCleared extends SaleEvent {
  const new();
}

/// Synchronizes [SaleState] with the latest [PosRepository] state.
final class SalePosStateUpdated extends SaleEvent {
  const new();
}

/// Immutable state for `SaleBloc`. All monetary and quantity totals are
/// delegated to `app/lib/domain/` functions.
class SaleState extends Equatable {
  const new({
    required this.posState,
    required this.tableId,
    required this.pkgId,
    required this.timing,
    required this.a,
    required this.c,
    required this.f,
    required this.ad,
    required this.notes,
    required this.selectedCategory,
    this.toastMessage = '',
    this.now,
  });

  final PosState posState;
  final String tableId;
  final String pkgId;
  final String timing;
  final int a;
  final int c;
  final int f;
  final Map<String, int> ad;
  final String notes;
  final String selectedCategory;
  final String toastMessage;
  final DateTime? now;

  DiningTable? get table {
    for (final t in posState.tables) {
      if (t.id == tableId) return t;
    }
    return null;
  }

  OpenTableState? get openTable => posState.openTables[tableId];

  List<PackageItem> get activePackages =>
      posState.packages.where((p) => p.active).toList();

  List<AddonItem> get activeAddons =>
      posState.addons.where((x) => x.active).toList();

  PackageItem? get activePackage {
    final targetId = openTable?.packageId ?? pkgId;
    for (final p in posState.packages) {
      if (p.id == targetId) return p;
    }
    return activePackages.isNotEmpty ? activePackages.first : null;
  }

  String get effectiveTiming => openTable?.timing ?? timing;

  String get effectiveNotes => openTable?.notes ?? notes;

  List<String> get categories {
    final cats = <String>[if (openTable == null) 'แพ็กเกจ'];
    for (final x in activeAddons) {
      final cat = x.category.isNotEmpty ? x.category : 'เครื่องดื่ม';
      if (!cats.contains(cat)) cats.add(cat);
    }
    return cats;
  }

  String get activeCategory => categories.contains(selectedCategory)
      ? selectedCategory
      : (categories.isNotEmpty ? categories.first : '');

  TableTotals get sentTotals =>
      (openTable != null && effectiveTiming == 'after')
      ? tableTotals(openTable!)
      : TableTotals();

  TableTotals get cartTotals =>
      TableTotals(a: a, c: c, f: f, ad: Map<String, int>.from(ad));

  CalculatedOrder get cartOrder => orderOf(posState, activePackage, cartTotals);

  CalculatedOrder get payOrder => effectiveTiming == 'after'
      ? orderOf(posState, activePackage, mergeTotals(sentTotals, cartTotals))
      : cartOrder;

  List<SentLineItem> get sentRows =>
      (openTable != null && effectiveTiming == 'after')
      ? sentLines(posState, activePackage, sentTotals)
      : const <SentLineItem>[];

  double get due => openTable != null ? tableDue(posState, openTable!) : 0;

  TableTimerStatus? get timer =>
      openTable != null ? tableTimer(posState, openTable!, now: now) : null;

  bool get hasCart => !totalsEmpty(cartTotals);

  bool get canSend =>
      activePackage != null &&
      hasCart &&
      (openTable != null || (a + c + f) > 0);

  bool get canPay =>
      activePackage != null &&
      payOrder.total > 0 &&
      (openTable != null || (a + c + f) > 0);

  SaleState copyWith({
    PosState? posState,
    String? tableId,
    String? pkgId,
    String? timing,
    int? a,
    int? c,
    int? f,
    Map<String, int>? ad,
    String? notes,
    String? selectedCategory,
    String? toastMessage,
    DateTime? now,
  }) => SaleState(
    posState: posState ?? this.posState,
    tableId: tableId ?? this.tableId,
    pkgId: pkgId ?? this.pkgId,
    timing: timing ?? this.timing,
    a: a ?? this.a,
    c: c ?? this.c,
    f: f ?? this.f,
    ad: ad ?? this.ad,
    notes: notes ?? this.notes,
    selectedCategory: selectedCategory ?? this.selectedCategory,
    toastMessage: toastMessage ?? this.toastMessage,
    now: now ?? this.now,
  );

  @override
  List<Object?> get props => [
    posState,
    tableId,
    pkgId,
    timing,
    a,
    c,
    f,
    ad,
    notes,
    selectedCategory,
    toastMessage,
    now,
  ];
}
