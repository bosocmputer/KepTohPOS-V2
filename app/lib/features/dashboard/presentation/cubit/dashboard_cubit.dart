import 'dart:async';

import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Immutable state for [DashboardCubit] (`DashboardView` in
/// `prototype/index.html:1530-1582`).
class DashboardState extends Equatable {
  const new({
    required this.posState,
    required this.ledger,
    required this.summary,
    this.selectedBarDate,
  });

  final PosState posState;
  final LedgerResult ledger;
  final DashboardSummary summary;
  final String? selectedBarDate;

  String get range => summary.range;

  /// Day summary for the currently tapped bar in `ProfitChart`, if any.
  LedgerDaySummary? get selectedBarDay {
    final target = selectedBarDate;
    if (target == null) return null;
    for (final d in summary.days) {
      if (d.date == target) return d;
    }
    return null;
  }

  DashboardState copyWith({
    PosState? posState,
    LedgerResult? ledger,
    DashboardSummary? summary,
    String? selectedBarDate,
    bool clearSelectedBar = false,
  }) => DashboardState(
    posState: posState ?? this.posState,
    ledger: ledger ?? this.ledger,
    summary: summary ?? this.summary,
    selectedBarDate: clearSelectedBar
        ? null
        : (selectedBarDate ?? this.selectedBarDate),
  );

  @override
  List<Object?> get props => [
    posState,
    ledger,
    summary.range,
    summary.todayKey,
    summary.showNetProfit,
    summary.net,
    summary.profit,
    summary.netProfit,
    selectedBarDate,
  ];
}

/// Cubit managing `/dashboard` period selection and daily profit chart
/// inspection (`DashboardView` in `prototype/index.html`).
class DashboardCubit extends Cubit<DashboardState> {
  new(
    PosRepository repository, {
    DateTime? now,
    DateTime Function()? clock,
    String initialRange = '30',
  }) : _repository = repository,
       _clock = clock ?? (() => now ?? DateTime.now()),
       super(
         _buildState(
           repository.state,
           range: initialRange,
           today: dkey((clock ?? (() => now ?? DateTime.now()))()),
         ),
       ) {
    _sub = _repository.stream.listen((s) {
      if (!isClosed) {
        emit(
          _buildState(
            s,
            range: state.range,
            today: dkey(_clock()),
            selectedBarDate: state.selectedBarDate,
          ),
        );
      }
    });
  }

  final PosRepository _repository;
  final DateTime Function() _clock;
  StreamSubscription<PosState>? _sub;

  static DashboardState _buildState(
    PosState s, {
    required String range,
    required String today,
    String? selectedBarDate,
  }) {
    final ledger = computeLedger(s, today: today);
    final summary = computeDashboardSummary(
      s,
      ledger,
      range: range,
      today: today,
    );
    final keepBar =
        selectedBarDate != null &&
        summary.days.any((d) => d.date == selectedBarDate);
    return DashboardState(
      posState: s,
      ledger: ledger,
      summary: summary,
      selectedBarDate: keepBar ? selectedBarDate : null,
    );
  }

  /// Switches the dashboard range (`'today'`, `'7'`, `'month'`, `'30'`).
  void setRange(String range) {
    final summary = computeDashboardSummary(
      state.posState,
      state.ledger,
      range: range,
      today: state.summary.todayKey,
    );
    final keepBar =
        state.selectedBarDate != null &&
        summary.days.any((d) => d.date == state.selectedBarDate);
    emit(
      state.copyWith(
        summary: summary,
        selectedBarDate: keepBar ? state.selectedBarDate : null,
        clearSelectedBar: !keepBar,
      ),
    );
  }

  /// Selects or toggles a day bar in `ProfitChart` to display its date and
  /// profit/loss amount.
  void selectBarDate(String? date) {
    final next = date == state.selectedBarDate ? null : date;
    emit(state.copyWith(selectedBarDate: next, clearSelectedBar: next == null));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
