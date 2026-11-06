import 'dart:async';

import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Immutable state for [AuthCubit].
class AuthState extends Equatable {
  const new({
    required this.staff,
    required this.selectedStaffId,
    this.pin = '',
    this.error = '',
    this.currentStaff,
    this.hasOpenShift = false,
    this.shouldPromptOpenShift = false,
    this.lastClosedDay,
    this.heroProfitValue = 0,
    this.showNetProfit = true,
  });

  final List<StaffMember> staff;
  final String selectedStaffId;
  final String pin;
  final String error;
  final StaffMember? currentStaff;
  final bool hasOpenShift;
  final bool shouldPromptOpenShift;
  final LedgerDaySummary? lastClosedDay;
  final double heroProfitValue;
  final bool showNetProfit;

  bool get isAuthenticated => currentStaff != null;

  StaffMember? get selectedStaff {
    for (final s in staff) {
      if (s.id == selectedStaffId) return s;
    }
    return staff.isNotEmpty ? staff.first : null;
  }

  AuthState copyWith({
    List<StaffMember>? staff,
    String? selectedStaffId,
    String? pin,
    String? error,
    StaffMember? Function()? currentStaff,
    bool? hasOpenShift,
    bool? shouldPromptOpenShift,
    LedgerDaySummary? Function()? lastClosedDay,
    double? heroProfitValue,
    bool? showNetProfit,
  }) => AuthState(
    staff: staff ?? this.staff,
    selectedStaffId: selectedStaffId ?? this.selectedStaffId,
    pin: pin ?? this.pin,
    error: error ?? this.error,
    currentStaff: currentStaff != null ? currentStaff() : this.currentStaff,
    hasOpenShift: hasOpenShift ?? this.hasOpenShift,
    shouldPromptOpenShift: shouldPromptOpenShift ?? this.shouldPromptOpenShift,
    lastClosedDay: lastClosedDay != null ? lastClosedDay() : this.lastClosedDay,
    heroProfitValue: heroProfitValue ?? this.heroProfitValue,
    showNetProfit: showNetProfit ?? this.showNetProfit,
  );

  @override
  List<Object?> get props => [
    staff.map((s) => '${s.id}:${s.name}:${s.role}:${s.pin}').toList(),
    selectedStaffId,
    pin,
    error,
    currentStaff?.id,
    hasOpenShift,
    shouldPromptOpenShift,
    lastClosedDay?.date,
    heroProfitValue,
    showNetProfit,
  ];
}

/// Manages PIN authentication, session staff, and Login hero ledger summary.
class AuthCubit extends Cubit<AuthState> {
  new(PosRepository repository, {DateTime? now, DateTime Function()? clock})
    : _repository = repository,
      _clock = clock ?? (now != null ? () => now : DateTime.now),
      super(
        _buildStateFromRepo(
          repository,
          now: (clock ?? (now != null ? () => now : DateTime.now))(),
        ),
      ) {
    _sub = _repository.stream.listen((_) {
      if (!_mutatingSession) _syncFromRepo();
    });
  }

  final PosRepository _repository;
  final DateTime Function() _clock;
  StreamSubscription<PosState>? _sub;
  bool _mutatingSession = false;

  static AuthState _buildStateFromRepo(
    PosRepository repo, {
    required DateTime now,
    String? selectedStaffId,
    String pin = '',
    String error = '',
    bool shouldPromptOpenShift = false,
  }) {
    final s = repo.state;
    final activeStaff = s.staff.where((x) => x.active).toList();
    var selId = selectedStaffId ?? s.currentStaffId;
    if (!activeStaff.any((x) => x.id == selId)) {
      selId = activeStaff.isNotEmpty ? activeStaff.first.id : '';
    }
    final ledger = computeLedger(
      s,
      today: businessDayKey(now, s.shop.dayCutoffMinutes),
    );
    LedgerDaySummary? lastClosed;
    for (var i = ledger.days.length - 1; i >= 0; i--) {
      if (ledger.days[i].closed) {
        lastClosed = ledger.days[i];
        break;
      }
    }
    final showNet = s.shop.showNetProfit;
    final heroVal = lastClosed != null
        ? ((showNet ? lastClosed.netProfit : lastClosed.profit) ?? 0.0)
        : 0.0;

    return AuthState(
      staff: activeStaff,
      selectedStaffId: selId,
      pin: pin,
      error: error,
      currentStaff: repo.currentStaff,
      hasOpenShift: openShiftOf(s) != null,
      shouldPromptOpenShift: shouldPromptOpenShift,
      lastClosedDay: lastClosed,
      heroProfitValue: heroVal,
      showNetProfit: showNet,
    );
  }

  void _syncFromRepo({bool? shouldPromptOpenShift}) {
    final hasShift = openShiftOf(_repository.state) != null;
    emit(
      _buildStateFromRepo(
        _repository,
        now: _clock(),
        selectedStaffId: state.selectedStaffId,
        pin: state.pin,
        error: state.error,
        shouldPromptOpenShift:
            shouldPromptOpenShift ?? (state.shouldPromptOpenShift && !hasShift),
      ),
    );
  }

  /// Selects a staff member in the login dropdown and resets PIN/error.
  void selectStaff(String staffId) {
    emit(state.copyWith(selectedStaffId: staffId, pin: '', error: ''));
  }

  /// Updates the current PIN input and clears any previous error.
  void setPin(String value) {
    emit(state.copyWith(pin: value, error: ''));
  }

  /// Validates the 4-digit PIN and logs in when valid (`submit` in `Login`).
  bool submitPin([String? pinOverride]) {
    final who = state.selectedStaff;
    if (who == null) return false;
    final v = pinOverride ?? state.pin;
    if (v.length != 4) {
      emit(state.copyWith(error: 'ใส่ PIN ให้ครบ 4 หลัก'));
      return false;
    }
    if (v != who.pin) {
      emit(state.copyWith(pin: '', error: 'PIN ไม่ถูกต้อง ลองใหม่อีกครั้ง'));
      return false;
    }
    _mutatingSession = true;
    _repository.setSessionStaffId(who.id);
    _mutatingSession = false;
    final hasShift = openShiftOf(_repository.state) != null;
    _syncFromRepo(shouldPromptOpenShift: !hasShift);
    return true;
  }

  /// Dismisses the post-login Open Shift modal prompt.
  void dismissOpenShiftPrompt() {
    emit(state.copyWith(shouldPromptOpenShift: false));
  }

  /// Signs out the current staff member (`logout` in `prototype/index.html`).
  void logout() {
    _mutatingSession = true;
    _repository.setSessionStaffId(null);
    _mutatingSession = false;
    emit(
      _buildStateFromRepo(
        _repository,
        now: _clock(),
        selectedStaffId: state.selectedStaffId,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
