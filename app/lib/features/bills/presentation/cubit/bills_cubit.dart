import 'dart:async';
import 'dart:math' as math;

import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Immutable state for [BillsCubit] (`BillsView` in `prototype/index.html`).
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

  /// All bills for [selectedDate], sorted newest to oldest.
  List<BillRecord> get dayBills {
    final list = posState.sales.where((b) => b.date == selectedDate).toList()
      ..sort((x, y) => y.at.compareTo(x.at));
    return list;
  }

  /// Non-voided bills for [selectedDate].
  List<BillRecord> get okBills => dayBills.where((b) => !b.voided).toList();

  /// Count of voided bills for [selectedDate].
  int get voidedCount => dayBills.length - okBills.length;

  /// Total revenue for [selectedDate] excluding voided bills.
  double get totalSales => okBills.fold<double>(0, (a, b) => a + b.total);

  /// Paid heads (`adult + child`) for [selectedDate] excluding voided bills.
  int get totalPaidHeads =>
      okBills.fold<int>(0, (a, b) => a + b.heads.a + b.heads.c);

  /// Free toddler heads (`f`) for [selectedDate] excluding voided bills.
  int get totalFreeHeads => okBills.fold<int>(0, (a, b) => a + b.heads.f);

  /// Sales breakdown by payment method name (`byMethod` in `BillsView`).
  Map<String, double> get salesByMethod {
    final map = <String, double>{};
    for (final b in okBills) {
      map[b.methodName] = (map[b.methodName] ?? 0) + b.total;
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
  BillRecord? get selectedBill {
    final id = selectedBillId;
    if (id == null) return null;
    for (final b in posState.sales) {
      if (b.id == id) return b;
    }
    return null;
  }

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
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
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
  ];
}

/// Cubit managing daily sales bills, filters, pagination, and voiding
/// (`BillsView` in `prototype/index.html`).
class BillsCubit extends Cubit<BillsState> {
  new(PosRepository repository, {DateTime? now, String? initialDate})
    : _repository = repository,
      _fixedNow = now,
      super(
        _initialState(repository.state, now: now, initialDate: initialDate),
      ) {
    _sub = _repository.stream.listen((s) {
      if (!isClosed) {
        emit(state.copyWith(posState: s));
      }
    });
  }

  final PosRepository _repository;
  final DateTime? _fixedNow;
  StreamSubscription<PosState>? _sub;

  static String _resolveToday(PosState s, DateTime? now) {
    final currentNow = now ?? DateTime.now();
    var tk = dkey(currentNow);
    if (!s.sales.any((b) => b.date == tk) && s.sales.isNotEmpty) {
      tk = s.sales
          .map((b) => b.date)
          .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    }
    return tk;
  }

  static BillsState _initialState(
    PosState s, {
    DateTime? now,
    String? initialDate,
  }) {
    final tk = _resolveToday(s, now);
    return BillsState(
      posState: s,
      selectedDate: initialDate ?? tk,
      todayDate: tk,
      now: now,
    );
  }

  void setDate(String date) =>
      emit(state.copyWith(selectedDate: date, page: 1));

  void setSearchQuery(String query) =>
      emit(state.copyWith(searchQuery: query, page: 1));

  void toggleMethodFilter(String methodId) {
    final next = Set<String>.from(state.selectedMethodIds);
    if (!next.remove(methodId)) {
      next.add(methodId);
    }
    emit(state.copyWith(selectedMethodIds: next, page: 1));
  }

  void setStatusFilter(String status) =>
      emit(state.copyWith(statusFilter: status, page: 1));

  void clearFilters() => emit(
    state.copyWith(
      selectedMethodIds: const <String>{},
      statusFilter: 'all',
      page: 1,
    ),
  );

  void setFilterDrawerOpen({required bool open}) =>
      emit(state.copyWith(filterDrawerOpen: open));

  void setPage(int page) => emit(state.copyWith(page: page));

  void selectBill(String? billId) => emit(
    state.copyWith(selectedBillId: billId, clearSelectedBill: billId == null),
  );

  void clearToast() => emit(state.copyWith(toastMessage: ''));

  /// Voids [billId] (or `state.selectedBillId`) and restores addon stock.
  /// Returns `false` if `staff.role == 'cashier'`, not found, or already
  /// voided.
  bool voidBillById({
    required StaffMember staff,
    String? billId,
    String reason = '',
  }) {
    final targetId = billId ?? state.selectedBillId;
    if (targetId == null || staff.role == 'cashier') return false;
    BillRecord? bill;
    for (final b in _repository.state.sales) {
      if (b.id == targetId) {
        bill = b;
        break;
      }
    }
    if (bill == null || bill.voided) return false;
    final billNo = bill.no;
    var ok = false;
    _repository.update((st) {
      ok = voidBill(
        st,
        billId: targetId,
        me: staff,
        reason: reason,
        now: _fixedNow ?? state.now,
      );
    });
    if (ok) {
      emit(
        state.copyWith(
          posState: _repository.state,
          toastMessage: 'ยกเลิกบิล $billNo แล้ว',
        ),
      );
    }
    return ok;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
