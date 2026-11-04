import 'dart:async';

import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/bloc/stock_count_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/stock/presentation/bloc/stock_count_state.dart';

/// BLoC managing the fast daily/weekly stock counting flow (`StockCount` in
/// `prototype/index.html:1352-1417`).
class StockCountBloc extends Bloc<StockCountEvent, StockCountState> {
  new({
    required PosRepository repository,
    DateTime? now,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock ?? (now != null ? () => now : DateTime.now),
       super(
         _initialState(
           repository,
           (clock ?? (now != null ? () => now : DateTime.now))(),
         ),
       ) {
    on<StockCountRepositoryUpdated>(_onRepositoryUpdated);
    on<StockCountDateChanged>(_onDateChanged);
    on<StockCountItemSelected>(_onItemSelected);
    on<StockCountValueChanged>(_onValueChanged);
    on<StockCountNextPressed>(_onNextPressed);
    on<StockCountPadToggled>(_onPadToggled);
    on<StockCountDraftCancelled>(_onDraftCancelled);
    on<StockCountSaved>(_onSaved);
    on<StockCountDayReopened>(_onDayReopened);
    on<StockCountToastCleared>(_onToastCleared);

    _sub = _repository.stream.listen((s) {
      add(StockCountRepositoryUpdated(s));
    });
  }

  final PosRepository _repository;
  final DateTime Function() _clock;
  StreamSubscription<PosState>? _sub;

  static StockCountState _initialState(PosRepository repo, DateTime now) {
    final s = repo.state;
    final today = dkey(now);
    final ledger = computeLedger(s, today: today);
    return StockCountState(
      posState: s,
      ledger: ledger,
      todayDate: today,
      selectedDate: today,
    );
  }

  void _onRepositoryUpdated(
    StockCountRepositoryUpdated event,
    Emitter<StockCountState> emit,
  ) {
    final today = dkey(_clock());
    final ledger = computeLedger(event.posState, today: today);
    emit(
      state.copyWith(
        posState: event.posState,
        ledger: ledger,
        todayDate: today,
      ),
    );
  }

  void _onDateChanged(
    StockCountDateChanged event,
    Emitter<StockCountState> emit,
  ) {
    if (event.date.isEmpty || event.date == state.selectedDate) return;
    emit(
      state.copyWith(
        selectedDate: event.date,
        draft: null,
        activeId: null,
        padOpen: false,
      ),
    );
  }

  void _onItemSelected(
    StockCountItemSelected event,
    Emitter<StockCountState> emit,
  ) {
    emit(state.copyWith(activeId: event.ingredientId, padOpen: true));
  }

  void _onValueChanged(
    StockCountValueChanged event,
    Emitter<StockCountState> emit,
  ) {
    final cur = state.currentIngredientId;
    if (cur == null) return;
    final ing = state.currentIngredient;
    var clean = event.value;
    if (ing != null && isDiscreteUnit(ing.unit)) {
      clean = clean.replaceAll('.', '');
    }
    final nextDraft = Map<String, String>.from(state.values)..[cur] = clean;
    emit(state.copyWith(activeId: cur, draft: nextDraft));
  }

  void _onNextPressed(
    StockCountNextPressed event,
    Emitter<StockCountState> emit,
  ) {
    final cur = state.currentIngredientId;
    final order = state.orderedIngredients;
    if (cur == null || order.isEmpty) return;
    final idx = order.indexWhere((x) => x.id == cur);
    if (idx < 0) return;
    final after = order.sublist(idx + 1);
    final vals = state.values;
    final nextEmptyDue = after
        .where(
          (x) =>
              isIngredientDue(state.posState, x, state.selectedDate) &&
              (vals[x.id] ?? '').isEmpty,
        )
        .firstOrNull;
    final nextEmpty = after
        .where((x) => (vals[x.id] ?? '').isEmpty)
        .firstOrNull;
    final nextItem =
        nextEmptyDue ?? nextEmpty ?? (after.isNotEmpty ? after.first : null);
    if (nextItem != null) {
      emit(state.copyWith(activeId: nextItem.id));
    }
  }

  void _onPadToggled(
    StockCountPadToggled event,
    Emitter<StockCountState> emit,
  ) {
    emit(state.copyWith(padOpen: event.open ?? !state.padOpen));
  }

  void _onDraftCancelled(
    StockCountDraftCancelled event,
    Emitter<StockCountState> emit,
  ) {
    emit(state.copyWith(draft: null, activeId: null));
  }

  void _onSaved(StockCountSaved event, Emitter<StockCountState> emit) {
    if (!state.canSave) return;
    final date = state.selectedDate;
    final draftValues = Map<String, String>.from(state.values);
    _repository.update((st) {
      saveDailyCount(st, date: date, draftValues: draftValues);
    });
    final s = _repository.state;
    final today = dkey(_clock());
    final ledger = computeLedger(s, today: today);
    emit(
      state.copyWith(
        posState: s,
        ledger: ledger,
        todayDate: today,
        draft: null,
        toastMessage: 'บันทึกยอดคงเหลือและปิดวันแล้ว',
      ),
    );
  }

  void _onDayReopened(
    StockCountDayReopened event,
    Emitter<StockCountState> emit,
  ) {
    if (event.staff.role == 'cashier') return;
    final date = state.selectedDate;
    var reopened = false;
    _repository.update((st) {
      reopened = reopenClosedDay(st, date: date, me: event.staff);
    });
    if (!reopened) return;
    final s = _repository.state;
    final today = dkey(_clock());
    final ledger = computeLedger(s, today: today);
    emit(
      state.copyWith(
        posState: s,
        ledger: ledger,
        todayDate: today,
        draft: null,
        toastMessage: 'ยกเลิกการปิดวันแล้ว',
      ),
    );
  }

  void _onToastCleared(
    StockCountToastCleared event,
    Emitter<StockCountState> emit,
  ) {
    if (state.toastMessage.isEmpty) return;
    emit(state.copyWith(toastMessage: ''));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
