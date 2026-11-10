import 'dart:math' as math;

import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';

/// Immutable state for `BillsCubit` (`BillsView` in `prototype/index.html`).
class BillsState extends Equatable {
  const new({
    required this.posState,
    required this.selectedDate,
    required this.todayDate,
    this.searchQuery = '',
    this.selectedMethodIds = const <String>{},
    this.statusFilter = 'all',
    this.page = 1,
    this.selectedBillId,
    this.filterDrawerOpen = false,
    this.toastMessage = '',
    this.now,
    this.olderBills = const <BillRecord>[],
    this.olderFailed = false,
  });

  static const int perPage = 10;

  final PosState posState;
  final String selectedDate;
  final String todayDate;
  final String searchQuery;
  final Set<String> selectedMethodIds;
  final String statusFilter;
  final int page;
  final String? selectedBillId;
  final bool filterDrawerOpen;
  final String toastMessage;
  final DateTime? now;

  /// Bills fetched on demand when [selectedDate] is before `posState.rawFrom`.
  final List<BillRecord> olderBills;

  /// The on-demand fetch for [selectedDate] failed (offline).
  final bool olderFailed;

  /// Whether [selectedDate] is older than the raw bills in [posState].
  bool get isOlderDay =>
      posState.rawFrom != null && selectedDate.compareTo(posState.rawFrom!) < 0;

  /// All bills for [selectedDate], sorted newest to oldest.
  List<BillRecord> get dayBills {
    final list =
        (isOlderDay
                ? olderBills
                : posState.sales.where((b) => b.date == selectedDate))
            .toList()
          ..sort((x, y) => y.at.compareTo(x.at));
    return list;
  }

  /// Non-voided bills for [selectedDate].
  List<BillRecord> get okBills => dayBills.where((b) => !b.voided).toList();

  /// Count of voided bills for [selectedDate].
  int get voidedCount => dayBills.length - okBills.length;

  /// Total revenue for [selectedDate] excluding voided bills.
  double get totalSales => okBills.fold<double>(0, (a, b) => a + b.total);

  /// Total Output VAT (`ภาษีขายรวม`) for [selectedDate] excluding voided bills.
  double get totalVat => okBills.fold<double>(0, (a, b) => a + b.vat);

  /// Total Pre-VAT base (`มูลค่าก่อนภาษี`) for [selectedDate].
  double get totalPreVat => totalSales - totalVat;

  /// Paid heads (`adult + child`) for [selectedDate] excluding voided bills.
  int get totalPaidHeads =>
      okBills.fold<int>(0, (a, b) => a + b.heads.a + b.heads.c);

  /// Free toddler heads (`f`) for [selectedDate] excluding voided bills.
  int get totalFreeHeads => okBills.fold<int>(0, (a, b) => a + b.heads.f);

  /// Sales breakdown by payment method (and bank account when present).
  Map<String, double> get salesByMethod {
    final map = <String, double>{};
    for (final b in okBills) {
      final acct = (b.bankAccountInfo ?? '').trim();
      final key = acct.isNotEmpty ? '${b.methodName} ($acct)' : b.methodName;
      map[key] = (map[key] ?? 0) + b.total;
    }
    return map;
  }

  /// Number of active filter criteria (`selectedMethodIds` + `statusFilter`).
  int get activeFilterCount =>
      selectedMethodIds.length + (statusFilter != 'all' ? 1 : 0);

  /// Bills on [selectedDate] matching [searchQuery], [selectedMethodIds], and
  /// [statusFilter].
  List<BillRecord> get filteredBills {
    final q = searchQuery.trim().toLowerCase();
    return dayBills.where((b) {
      if (statusFilter == 'ok' && b.voided) return false;
      if (statusFilter == 'void' && !b.voided) return false;
      if (selectedMethodIds.isNotEmpty &&
          !selectedMethodIds.contains(b.methodId)) {
        return false;
      }
      if (q.isEmpty) return true;
      return b.no.toLowerCase().contains(q) ||
          b.tableName.toLowerCase().contains(q) ||
          b.methodName.toLowerCase().contains(q) ||
          (b.bankAccountInfo ?? '').toLowerCase().contains(q) ||
          b.staffName.toLowerCase().contains(q);
    }).toList();
  }

  /// Total pagination pages (`10` rows per page).
  int get totalPages => math.max(1, (filteredBills.length / perPage).ceil());

  /// Clamped 1-based current page index.
  int get currentPage => page.clamp(1, totalPages);

  /// Visible slice of [filteredBills] for [currentPage].
  List<BillRecord> get pagedBills =>
      filteredBills.skip((currentPage - 1) * perPage).take(perPage).toList();

  /// Currently opened bill in `ReceiptModal`, if any.
  BillRecord? get selectedBill => [
    ...posState.sales,
    ...olderBills,
  ].where((b) => b.id == selectedBillId).firstOrNull;

  /// Number of the voided bill that [b] replaces, if known.
  String? replacesNoOf(BillRecord b) => b.replacesBillId == null
      ? null
      : [
          ...posState.sales,
          ...olderBills,
        ].where((o) => o.id == b.replacesBillId).firstOrNull?.no;

  /// Owner/manager may reissue an unvoided bill of the current month.
  bool canReissue(BillRecord b, StaffMember staff) =>
      staff.role != 'cashier' &&
      !b.voided &&
      !b.isSlipPreview &&
      !b.isFullInvoice &&
      b.date.startsWith(todayDate.substring(0, 7));

  /// Selectable dates from `posState.startDate` through [todayDate].
  List<String> get availableDates {
    final set = <String>{selectedDate, todayDate};
    final start = DateTime.tryParse(posState.startDate);
    final end = DateTime.tryParse(todayDate);
    if (start != null && end != null && !start.isAfter(end)) {
      var cur = start;
      while (!cur.isAfter(end)) {
        set.add(dkey(cur));
        cur = addDays(cur, 1);
      }
    }
    for (final b in posState.sales) {
      set.add(b.date);
    }
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  BillsState copyWith({
    PosState? posState,
    String? selectedDate,
    String? todayDate,
    String? searchQuery,
    Set<String>? selectedMethodIds,
    String? statusFilter,
    int? page,
    String? selectedBillId,
    bool clearSelectedBill = false,
    bool? filterDrawerOpen,
    String? toastMessage,
    DateTime? now,
    List<BillRecord>? olderBills,
    bool? olderFailed,
  }) => BillsState(
    posState: posState ?? this.posState,
    selectedDate: selectedDate ?? this.selectedDate,
    todayDate: todayDate ?? this.todayDate,
    searchQuery: searchQuery ?? this.searchQuery,
    selectedMethodIds: selectedMethodIds ?? this.selectedMethodIds,
    statusFilter: statusFilter ?? this.statusFilter,
    page: page ?? this.page,
    selectedBillId: clearSelectedBill
        ? null
        : (selectedBillId ?? this.selectedBillId),
    filterDrawerOpen: filterDrawerOpen ?? this.filterDrawerOpen,
    toastMessage: toastMessage ?? this.toastMessage,
    now: now ?? this.now,
    olderBills: olderBills ?? this.olderBills,
    olderFailed: olderFailed ?? this.olderFailed,
  );

  @override
  List<Object?> get props => [
    posState,
    selectedDate,
    todayDate,
    searchQuery,
    selectedMethodIds,
    statusFilter,
    page,
    selectedBillId,
    filterDrawerOpen,
    toastMessage,
    now,
    olderBills,
    olderFailed,
  ];
}
