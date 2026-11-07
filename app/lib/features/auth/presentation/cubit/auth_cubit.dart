import 'dart:async';

import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Immutable state for [AuthCubit].
class AuthState extends Equatable {
  const new({
    required this.staff,
    required this.selectedStaffId,
    this.pin = '',
    this.error = '',
    this.isDemoData = true,
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

  /// Whether sample wording and demo PIN hints may be shown.
  final bool isDemoData;

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
    isDemoData: isDemoData,
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
    // Without cost data the login card would show a wrong profit, so hide it.
    LedgerDaySummary? lastClosed;
    for (var i = repo.canReadCosts ? ledger.days.length - 1 : -1; i >= 0; i--) {
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
      isDemoData: repo.isDemoData,
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
  Future<bool> submitPin([String? pinOverride]) async {
    final who = state.selectedStaff;
    if (who == null) return false;
    final v = pinOverride ?? state.pin;
    if (v.length != 4) {
      emit(state.copyWith(error: 'ใส่ PIN ให้ครบ 4 หลัก'));
      return false;
    }
    _mutatingSession = true;
    final PinSignInResult result;
    try {
      result = await _repository.signInWithPin(who.id, v);
    } on PosCommandException catch (e) {
      emit(state.copyWith(pin: '', error: e.message));
      return false;
    } finally {
      _mutatingSession = false;
    }
    if (result != PinSignInResult.success) {
      final message = result == PinSignInResult.locked
          ? 'ใส่ PIN ผิดหลายครั้ง กรุณาลองใหม่ภายหลัง'
          : 'PIN ไม่ถูกต้อง ลองใหม่อีกครั้ง';
      emit(state.copyWith(pin: '', error: message));
      return false;
    }
    final hasShift = openShiftOf(_repository.state) != null;
    _syncFromRepo(shouldPromptOpenShift: !hasShift);
    return true;
  }

  /// Dismisses the post-login Open Shift modal prompt.
  void dismissOpenShiftPrompt() {
    emit(state.copyWith(shouldPromptOpenShift: false));
  }

  /// Signs out the current staff member (`logout` in `prototype/index.html`).
  Future<void> logout() async {
    _mutatingSession = true;
    try {
      await _repository.signOutStaff();
    } finally {
      _mutatingSession = false;
    }
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
