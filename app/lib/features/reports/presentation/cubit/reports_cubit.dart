import 'dart:async';

import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Immutable state for [ReportsCubit] (`ReportsView` in
/// `prototype/index.html:1585-1615`).
class ReportsState extends Equatable {
  const new({
    required this.posState,
    required this.ledger,
    required this.report,
  });

  final PosState posState;
  final LedgerResult ledger;
  final MonthlyReportSummary report;

  String get selectedMonth => report.selectedMonth;
  List<String> get availableMonths => report.availableMonths;

  @override
  List<Object?> get props => [
    posState,
    ledger,
    report.selectedMonth,
    report.showNetProfit,
    report.totalNet,
    report.closedProfit,
    report.closedNetProfit,
  ];
}

/// Cubit managing `/reports` monthly selection and daily ledger summary
/// (`ReportsView` in `prototype/index.html`).
class ReportsCubit extends Cubit<ReportsState> {
  new(
    PosRepository repository, {
    DateTime? now,
    DateTime Function()? clock,
    String? initialMonth,
  }) : _repository = repository,
       _clock = clock ?? (() => now ?? DateTime.now()),
       super(
         _buildState(
           repository.state,
           today: dkey((clock ?? (() => now ?? DateTime.now()))()),
           month: initialMonth,
         ),
       ) {
    _sub = _repository.stream.listen((s) {
      if (!isClosed) {
        emit(_buildState(s, today: dkey(_clock()), month: state.selectedMonth));
      }
    });
  }

  final PosRepository _repository;
  final DateTime Function() _clock;
  StreamSubscription<PosState>? _sub;

  static ReportsState _buildState(
    PosState s, {
    required String today,
    String? month,
  }) {
    final ledger = computeLedger(s, today: today);
    final report = computeMonthlyReport(s, ledger, month: month);
    return ReportsState(posState: s, ledger: ledger, report: report);
  }

  /// Switches the active report month (`YYYY-MM`).
  void setMonth(String month) {
    final report = computeMonthlyReport(
      state.posState,
      state.ledger,
      month: month,
    );
    emit(
      ReportsState(
        posState: state.posState,
        ledger: state.ledger,
        report: report,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
