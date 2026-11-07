import 'dart:async';

import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Immutable state for [TablesCubit] (`TablesView` in `prototype/index.html`).
class TablesState extends Equatable {
  const new({
    required this.posState,
    required this.zones,
    required this.selectedZone,
    required this.searchQuery,
    required this.freeCount,
    required this.totalTables,
    required this.inStoreHeads,
    required this.todaySalesTotal,
    required this.todayBillsCount,
    required this.todayPaidHeads,
    required this.owingTablesCount,
    required this.owingTotal,
    required this.hasOpenShift,
    this.now,
  });

  final PosState posState;
  final List<String> zones;
  final String selectedZone;
  final String searchQuery;
  final int freeCount;
  final int totalTables;
  final int inStoreHeads;
  final double todaySalesTotal;
  final int todayBillsCount;
  final int todayPaidHeads;
  final int owingTablesCount;
  final double owingTotal;
  final bool hasOpenShift;
  final DateTime? now;

  /// Zones to render after applying [selectedZone] filter.
  List<String> get visibleZones =>
      selectedZone == 'all' || !zones.contains(selectedZone)
      ? zones
      : <String>[selectedZone];

  /// Tables belonging to [zone] matching [searchQuery].
  List<DiningTable> tablesInZone(String zone) {
    final q = searchQuery.trim().toLowerCase();
    return posState.tables.where((t) {
      final z = t.zone.isNotEmpty ? t.zone : 'โต๊ะ';
      if (z != zone) return false;
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q) || z.toLowerCase().contains(q);
    }).toList();
  }

  /// Number of free tables in [zone] (unfiltered by search query).
  int freeInZone(String zone) {
    var count = 0;
    for (final t in posState.tables) {
      final z = t.zone.isNotEmpty ? t.zone : 'โต๊ะ';
      if (z == zone && !posState.openTables.containsKey(t.id)) {
        count++;
      }
    }
    return count;
  }

  /// Total tables in [zone] (unfiltered by search query).
  int totalInZone(String zone) {
    var count = 0;
    for (final t in posState.tables) {
      final z = t.zone.isNotEmpty ? t.zone : 'โต๊ะ';
      if (z == zone) count++;
    }
    return count;
  }

  @override
  List<Object?> get props => [
    posState,
    zones,
    selectedZone,
    searchQuery,
    freeCount,
    totalTables,
    inStoreHeads,
    todaySalesTotal,
    todayBillsCount,
    todayPaidHeads,
    owingTablesCount,
    owingTotal,
    hasOpenShift,
    now,
  ];
}

/// Cubit managing the floor/zone table overview (`TablesView` in `index.html`).
class TablesCubit extends Cubit<TablesState> {
  new(PosRepository repository, {DateTime? now})
    : _repository = repository,
      _fixedNow = now,
      super(_buildState(repository.state, now: now)) {
    _sub = _repository.stream.listen((_) => refresh());
  }

  final PosRepository _repository;
  final DateTime? _fixedNow;
  StreamSubscription<PosState>? _sub;

  static TablesState _buildState(
    PosState s, {
    String selectedZone = 'all',
    String searchQuery = '',
    DateTime? now,
  }) {
    final zones = <String>[];
    for (final t in s.tables) {
      final z = t.zone.isNotEmpty ? t.zone : 'โต๊ะ';
      if (!zones.contains(z)) zones.add(z);
    }

    final currentNow = now ?? DateTime.now();
    // Derive today's date key from latest sales date if available in mock seed,
    // or dkey(currentNow).
    var tk = businessDayKey(currentNow, s.shop.dayCutoffMinutes);
    if (!s.sales.any((b) => b.date == tk) && s.sales.isNotEmpty) {
      tk = s.sales
          .map((b) => b.date)
          .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    }

    var todayTotal = 0.0;
    var todayBills = 0;
    var todayHeads = 0;
    for (final b in s.sales) {
      if (b.date == tk && !b.voided) {
        todayBills++;
        todayTotal += b.total;
        todayHeads += b.heads.a + b.heads.c;
      }
    }

    final occ = s.openTables.values.toList();
    var inStore = 0;
    var owingCount = 0;
    var owingSum = 0.0;
    for (final o in occ) {
      inStore += o.heads.a + o.heads.c + o.heads.f;
      final due = tableDue(s, o);
      if (due > 0) {
        owingCount++;
        owingSum += due;
      }
    }

    return TablesState(
      posState: s,
      zones: zones,
      selectedZone: selectedZone,
      searchQuery: searchQuery,
      freeCount: s.tables.length - occ.length,
      totalTables: s.tables.length,
      inStoreHeads: inStore,
      todaySalesTotal: todayTotal,
      todayBillsCount: todayBills,
      todayPaidHeads: todayHeads,
      owingTablesCount: owingCount,
      owingTotal: owingSum,
      hasOpenShift: openShiftOf(s) != null,
      now: now,
    );
  }

  /// Refreshes table statistics and timers from [PosRepository].
  void refresh({DateTime? now}) {
    emit(
      _buildState(
        _repository.state,
        selectedZone: state.selectedZone,
        searchQuery: state.searchQuery,
        now: now ?? _fixedNow ?? state.now,
      ),
    );
  }

  /// Filters tables by floor/zone (`'all'` for all zones).
  void selectZone(String zone) {
    emit(
      _buildState(
        _repository.state,
        selectedZone: zone,
        searchQuery: state.searchQuery,
        now: _fixedNow ?? state.now,
      ),
    );
  }

  /// Filters tables by search query.
  void setSearchQuery(String query) {
    emit(
      _buildState(
        _repository.state,
        selectedZone: state.selectedZone,
        searchQuery: query,
        now: _fixedNow ?? state.now,
      ),
    );
  }

  /// Builds the POS slip (`BillRecord`) for an occupied [tableId].
  BillRecord? tablePosSlip(String tableId) =>
      buildTablePosSlip(state.posState, tableId, now: _fixedNow ?? state.now);

  /// Cancels an unpaid open table (`cancelOpenTable`).
  Future<void> cancelTable(String tableId) async {
    await _repository.cancelTable(tableId);
    refresh();
  }

  /// Voids a settled table bill (`voidBill`) and releases the table if empty.
  Future<void> voidBill(String billId, String reason, StaffMember staff) async {
    await _repository.voidSale(
      billId: billId,
      staff: staff,
      allowCashier: true,
      reason: reason.trim().isEmpty ? 'ลูกค้าเปลี่ยนใจไม่รับประทาน' : reason,
      now: _fixedNow ?? state.now,
    );
    refresh();
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
