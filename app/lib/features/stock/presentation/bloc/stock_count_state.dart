import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';

/// Formats a numeric quantity using JS `String(num)` semantics (`12.0` ->
/// `'12'`, `1.5` -> `'1.5'`).
String formatJsNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

/// Events for `StockCountBloc`.
sealed class StockCountEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => <Object?>[];
}

/// Triggered when the underlying [PosRepository] state updates.
final class StockCountRepositoryUpdated extends StockCountEvent {
  const new(this.posState);

  final PosState posState;

  @override
  List<Object?> get props => <Object?>[posState];
}

/// Changes the counting date and resets unsaved draft values.
final class StockCountDateChanged extends StockCountEvent {
  const new(this.date);

  final String date;

  @override
  List<Object?> get props => <Object?>[date];
}

/// Toggles showing all ingredients vs only due/counted ingredients.
final class StockCountShowAllToggled extends StockCountEvent {
  const new({required this.showAll});

  final bool showAll;

  @override
  List<Object?> get props => <Object?>[showAll];
}

/// Selects a specific ingredient row for keypad input.
final class StockCountItemSelected extends StockCountEvent {
  const new(this.ingredientId);

  final String ingredientId;

  @override
  List<Object?> get props => <Object?>[ingredientId];
}

/// Updates the draft count string for the currently active ingredient.
final class StockCountValueChanged extends StockCountEvent {
  const new(this.value);

  final String value;

  @override
  List<Object?> get props => <Object?>[value];
}

/// Advances to the next uncounted (or next sequential) ingredient row.
final class StockCountNextPressed extends StockCountEvent {
  const new();
}

/// Toggles the mobile collapsible numpad panel (`<= 760px`).
final class StockCountPadToggled extends StockCountEvent {
  const new({this.open});

  final bool? open;

  @override
  List<Object?> get props => <Object?>[open];
}

/// Discards unsaved draft edits and restores saved counts for the date.
final class StockCountDraftCancelled extends StockCountEvent {
  const new();
}

/// Saves all counted values (rounded per unit via [roundQty]) and closes the
/// day.
final class StockCountSaved extends StockCountEvent {
  const new();
}

/// Reopens a closed day (`delete st.counts[date]`), restricted to
/// `manager` / `owner`.
final class StockCountDayReopened extends StockCountEvent {
  const new({required this.staff});

  final StaffMember staff;

  @override
  List<Object?> get props => <Object?>[staff];
}

/// Clears a transient toast notification after it is shown.
final class StockCountToastCleared extends StockCountEvent {
  const new();
}

/// Immutable state for `StockCountBloc` (`StockCount` in `index.html:1352`).
class StockCountState extends Equatable {
  const new({
    required this.posState,
    required this.ledger,
    required this.todayDate,
    required this.selectedDate,
    this.draft,
    this.showAll = false,
    this.activeId,
    this.padOpen = false,
    this.toastMessage = '',
  });

  final PosState posState;
  final LedgerResult ledger;
  final String todayDate;
  final String selectedDate;
  final Map<String, String>? draft;
  final bool showAll;
  final String? activeId;
  final bool padOpen;
  final String toastMessage;

  /// Ledger summary for [selectedDate].
  LedgerDaySummary? get daySummary => ledger.byDate[selectedDate];

  /// Whether [selectedDate] is already closed (`counts[date] != null`).
  bool get isClosed => daySummary?.closed ?? false;

  /// Whether the user has unsaved edits in [draft].
  bool get hasDraft => draft != null;

  /// Saved closing counts for [selectedDate].
  Map<String, double> get savedCounts =>
      posState.counts[selectedDate] ?? const <String, double>{};

  /// Current string values for every ingredient (`vals` in `index.html:1361`).
  Map<String, String> get values {
    if (draft != null) return draft!;
    final saved = savedCounts;
    return <String, String>{
      for (final ing in posState.ingredients)
        ing.id: saved.containsKey(ing.id) ? formatJsNumber(saved[ing.id]!) : '',
    };
  }

  /// Ingredients due to be counted on [selectedDate] (`due` in `index.html`).
  List<IngredientItem> get dueIngredients => posState.ingredients
      .where((i) => isIngredientDue(posState, i, selectedDate))
      .toList();

  /// Number of weekly ingredients skipped on [selectedDate].
  int get skippedWeeklyCount =>
      posState.ingredients.length - dueIngredients.length;

  /// Visible ingredients grouped by storage location (`groups` in
  /// `index.html`).
  List<MapEntry<String, List<IngredientItem>>> get locationGroups {
    final vals = values;
    final visible = showAll
        ? posState.ingredients
        : posState.ingredients
              .where(
                (i) =>
                    isIngredientDue(posState, i, selectedDate) ||
                    (vals[i.id] ?? '').isNotEmpty,
              )
              .toList();
    return groupIngredientsByLocation(visible);
  }

  /// Flattened display order of visible ingredients (`order` in `index.html`).
  List<IngredientItem> get orderedIngredients => <IngredientItem>[
    for (final entry in locationGroups) ...entry.value,
  ];

  /// Effective active ingredient ID (`cur` in `index.html:1374`).
  String? get currentIngredientId {
    final order = orderedIngredients;
    if (order.isEmpty) return null;
    if (activeId != null && order.any((i) => i.id == activeId)) {
      return activeId;
    }
    final vals = values;
    final firstEmpty = order
        .where((i) => (vals[i.id] ?? '').isEmpty)
        .firstOrNull;
    return (firstEmpty ?? order.first).id;
  }

  /// Effective active [IngredientItem] (`curIng` in `index.html:1375`).
  IngredientItem? get currentIngredient {
    final id = currentIngredientId;
    if (id == null) return null;
    return posState.ingredients.where((i) => i.id == id).firstOrNull;
  }

  /// Current string value in the keypad for [currentIngredientId].
  String get currentValue {
    final id = currentIngredientId;
    if (id == null) return '';
    return values[id] ?? '';
  }

  /// Number of due ingredients that have a non-empty value (`doneDue`).
  int get doneDueCount {
    final vals = values;
    return dueIngredients
        .where((i) => (vals[i.id] ?? '').trim().isNotEmpty)
        .length;
  }

  /// Whether all due ingredients have been counted (`doneDue == due.length`).
  bool get canSave {
    final due = dueIngredients;
    return due.isNotEmpty && doneDueCount == due.length;
  }

  /// Looks up the [IngredientDayRow] for [ingId] on [selectedDate].
  IngredientDayRow? rowOf(String ingId) =>
      daySummary?.rows.where((r) => r.ing.id == ingId).firstOrNull;

  /// Looks up the most recent previous count for [ingId] before [selectedDate].
  double? prevCountOf(String ingId) =>
      previousCountOf(posState, ingId, selectedDate);

  /// Computes live usage & cost preview for [ing].
  StockCountRowCalc calcOf(IngredientItem ing) => calcDraftCountRow(
    ing: ing,
    dayRow: rowOf(ing.id),
    draftValue: values[ing.id],
  );

  /// Sum of counted ingredient costs across all visible rows (`cp-sum` line 2).
  double get totalCountedCost => orderedIngredients.fold<double>(
    0,
    (sum, ing) => sum + (calcOf(ing).cost ?? 0),
  );

  static const Object _unset = Object();

  StockCountState copyWith({
    PosState? posState,
    LedgerResult? ledger,
    String? todayDate,
    String? selectedDate,
    Object? draft = _unset,
    bool? showAll,
    Object? activeId = _unset,
    bool? padOpen,
    String? toastMessage,
  }) => StockCountState(
    posState: posState ?? this.posState,
    ledger: ledger ?? this.ledger,
    todayDate: todayDate ?? this.todayDate,
    selectedDate: selectedDate ?? this.selectedDate,
    draft: identical(draft, _unset)
        ? this.draft
        : draft as Map<String, String>?,
    showAll: showAll ?? this.showAll,
    activeId: identical(activeId, _unset) ? this.activeId : activeId as String?,
    padOpen: padOpen ?? this.padOpen,
    toastMessage: toastMessage ?? this.toastMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    posState,
    ledger,
    todayDate,
    selectedDate,
    draft,
    showAll,
    activeId,
    padOpen,
    toastMessage,
  ];
}
