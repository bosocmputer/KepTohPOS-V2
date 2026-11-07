import 'dart:async';

import 'package:app/core/utils/formatters.dart';
import 'package:app/core/utils/sequential_events.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Base event for [ShiftBloc].
sealed class ShiftEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Synchronizes [ShiftState] with the latest [PosRepository] state.
final class ShiftRefreshed extends ShiftEvent {
  const new();
}

/// Updates the starting cash float input in `OpenShiftForm`.
final class ShiftFloatInputChanged extends ShiftEvent {
  const new(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}

/// Opens a new cashier shift (`OpenShiftForm` in `prototype/index.html`).
final class ShiftOpened extends ShiftEvent {
  const new({required this.staffId, this.floatAmount, this.now});
  final String staffId;
  final int? floatAmount;
  final DateTime? now;

  @override
  List<Object?> get props => [staffId, floatAmount, now];
}

/// Updates the counted drawer cash input in `ShiftView`.
final class ShiftCountedInputChanged extends ShiftEvent {
  const new(this.value);
  final String value;

  @override
  List<Object?> get props => [value];
}

/// Shows or hides the close-shift confirmation dialog.
final class ShiftConfirmCloseToggled extends ShiftEvent {
  const new({required this.show});
  final bool show;

  @override
  List<Object?> get props => [show];
}

/// Closes the currently open shift (`ShiftView` in `prototype/index.html`).
final class ShiftClosed extends ShiftEvent {
  const new({required this.staffId, this.counted, this.now});
  final String staffId;
  final int? counted;
  final DateTime? now;

  @override
  List<Object?> get props => [staffId, counted, now];
}

/// Clears the transient toast notification message.
final class ShiftToastCleared extends ShiftEvent {
  const new();
}

/// Immutable state for [ShiftBloc].
class ShiftState extends Equatable {
  const new({
    required this.posState,
    required this.history,
    required this.owingTables,
    required this.owedTotal,
    required this.floatInput,
    this.activeShift,
    this.activeStats,
    this.countedInput = '',
    this.confirmClose = false,
    this.toastMessage = '',
  });

  final PosState posState;
  final ShiftRecord? activeShift;
  final ShiftStats? activeStats;
  final List<ShiftRecord> history;
  final List<DiningTable> owingTables;
  final int owedTotal;
  final String floatInput;
  final String countedInput;
  final bool confirmClose;
  final String toastMessage;

  bool get isShiftOpen => activeShift != null;

  int? get countedValue {
    final parsed = double.tryParse(countedInput.replaceAll(',', '').trim());
    return parsed == null ? null : satangFromBaht(parsed);
  }

  /// Difference between counted cash and expected cash (`+counted - expected`).
  int? get diff => (activeStats != null && countedValue != null)
      ? countedValue! - activeStats!.expected
      : null;

  String staffNameOf(String staffId) {
    for (final s in posState.staff) {
      if (s.id == staffId) return s.name;
    }
    return '-';
  }

  ShiftStats statsOf(ShiftRecord sh) => calcShiftStats(posState, sh);

  ShiftState copyWith({
    String? floatInput,
    String? countedInput,
    bool? confirmClose,
    String? toastMessage,
  }) => ShiftState(
    posState: posState,
    activeShift: activeShift,
    activeStats: activeStats,
    history: history,
    owingTables: owingTables,
    owedTotal: owedTotal,
    floatInput: floatInput ?? this.floatInput,
    countedInput: countedInput ?? this.countedInput,
    confirmClose: confirmClose ?? this.confirmClose,
    toastMessage: toastMessage ?? this.toastMessage,
  );

  @override
  List<Object?> get props => [
    activeShift?.id,
    activeShift?.openedAt,
    activeShift?.closedAt,
    activeShift?.floatAmount,
    activeShift?.counted,
    activeStats?.bills,
    activeStats?.cash,
    activeStats?.qr,
    activeStats?.transfer,
    activeStats?.expected,
    history.length,
    history.firstOrNull?.id,
    history.firstOrNull?.closedAt,
    owingTables.length,
    owedTotal,
    floatInput,
    countedInput,
    confirmClose,
    toastMessage,
  ];
}

/// BLoC managing cashier shift opening, cash drawer counting, shift closing,
/// and 14-shift history (`ShiftView` & `OpenShiftForm` in `index.html`).
class ShiftBloc extends Bloc<ShiftEvent, ShiftState> {
  new(PosRepository repository)
    : _repository = repository,
      super(_buildState(repository.state)) {
    on<ShiftEvent>(_dispatch, transformer: sequentialEvents());

    _sub = _repository.stream.listen((_) => add(const ShiftRefreshed()));
  }

  final PosRepository _repository;
  StreamSubscription<PosState>? _sub;

  static ShiftState _buildState(
    PosState s, {
    String? floatInput,
    String countedInput = '',
    bool confirmClose = false,
    String toastMessage = '',
  }) {
    final active = openShiftOf(s);
    final activeStats = active != null ? calcShiftStats(s, active) : null;
    final closedShifts = s.shifts.where((x) => x.closedAt != null).toList()
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    final history = closedShifts.take(14).toList();

    final owing = <DiningTable>[];
    var owed = 0;
    for (final tb in s.tables) {
      final ot = s.openTables[tb.id];
      if (ot != null) {
        final due = tableDue(s, ot);
        if (due > 0) {
          owing.add(tb);
          owed += due;
        }
      }
    }

    final defFloat = bahtInputText(s.shop.defaultFloat);
    return ShiftState(
      posState: s,
      activeShift: active,
      activeStats: activeStats,
      history: history,
      owingTables: owing,
      owedTotal: owed,
      floatInput: floatInput ?? defFloat,
      countedInput: countedInput,
      confirmClose: confirmClose,
      toastMessage: toastMessage,
    );
  }

  /// Runs every event in one queue so async handlers cannot overlap.
  Future<void> _dispatch(ShiftEvent event, Emitter<ShiftState> emit) async {
    try {
      switch (event) {
        case final ShiftRefreshed e:
          _onRefreshed(e, emit);
        case final ShiftFloatInputChanged e:
          emit(state.copyWith(floatInput: e.value));
        case final ShiftOpened e:
          await _onOpened(e, emit);
        case final ShiftCountedInputChanged e:
          emit(state.copyWith(countedInput: e.value));
        case final ShiftConfirmCloseToggled e:
          emit(state.copyWith(confirmClose: e.show));
        case final ShiftClosed e:
          await _onClosed(e, emit);
        case ShiftToastCleared():
          emit(state.copyWith(toastMessage: ''));
      }
    } on PosCommandException catch (e) {
      emit(state.copyWith(toastMessage: e.message));
    }
  }

  void _onRefreshed(ShiftRefreshed event, Emitter<ShiftState> emit) {
    emit(
      _buildState(
        _repository.state,
        floatInput: state.floatInput,
        countedInput: state.countedInput,
        confirmClose: state.confirmClose,
        toastMessage: state.toastMessage,
      ),
    );
  }

  Future<void> _onOpened(ShiftOpened event, Emitter<ShiftState> emit) async {
    final cleaned = state.floatInput.replaceAll(',', '').trim();
    final amount = event.floatAmount ?? parseBaht(cleaned);
    final nextPos = await _repository.openCashShift(
      staffId: event.staffId,
      floatAmount: amount,
      now: event.now,
    );
    emit(_buildState(nextPos, toastMessage: 'เปิดกะแล้ว'));
  }

  Future<void> _onClosed(ShiftClosed event, Emitter<ShiftState> emit) async {
    final cnt = event.counted ?? state.countedValue;
    if (cnt == null) return;
    final nextPos = await _repository.closeCashShift(
      staffId: event.staffId,
      counted: cnt,
      now: event.now,
    );
    emit(_buildState(nextPos, toastMessage: 'ปิดกะแล้ว'));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
