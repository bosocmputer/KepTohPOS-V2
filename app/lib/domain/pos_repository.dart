import 'dart:async';

import 'package:app/domain/models.dart';

int _shiftCounter = 0;

String _nextShiftUid(DateTime now) {
  _shiftCounter = (_shiftCounter + 1) & 0xFFFFF;
  final ts = now.millisecondsSinceEpoch.toRadixString(36);
  final tail = ts.length > 4 ? ts.substring(ts.length - 4) : ts;
  return 'sh$tail${_shiftCounter.toRadixString(36).padLeft(4, '0')}';
}

/// Finds the currently open shift (`openShiftOf` in `prototype/index.html`).
ShiftRecord? openShiftOf(PosState s) {
  for (final sh in s.shifts) {
    if (sh.closedAt == null) return sh;
  }
  return null;
}

/// Aggregated shift sales and cash drawer stats (`stats(sh)` in `ShiftView`).
class ShiftStats {
  const new({
    required this.bills,
    required this.cash,
    required this.qr,
    required this.transfer,
    required this.expected,
  });

  final int bills;
  final double cash;
  final double qr;
  final double transfer;
  final double expected;
}

/// Computes [ShiftStats] for [sh] (`stats` in `ShiftView` of `index.html`).
ShiftStats calcShiftStats(PosState s, ShiftRecord sh) {
  var bills = 0;
  var cash = 0.0;
  var qr = 0.0;
  var transfer = 0.0;
  for (final b in s.sales) {
    if (b.shiftId != sh.id || b.voided) continue;
    bills++;
    switch (b.methodType) {
      case 'cash':
        cash += b.total;
      case 'qr':
        qr += b.total;
      case 'transfer' || 'card':
        transfer += b.total;
    }
  }
  return ShiftStats(
    bills: bills,
    cash: cash,
    qr: qr,
    transfer: transfer,
    expected: sh.floatAmount + cash,
  );
}

/// Opens a new shift (`OpenShiftForm` in `prototype/index.html`).
ShiftRecord openShift(
  PosState s, {
  required String staffId,
  required double floatAmount,
  DateTime? now,
  String? id,
}) {
  final current = now ?? DateTime.now();
  final sh = ShiftRecord(
    id: id ?? _nextShiftUid(current),
    staffId: staffId,
    openedAt: current.toUtc().toIso8601String(),
    floatAmount: floatAmount,
  );
  s.shifts.add(sh);
  return sh;
}

/// Closes the currently open shift (`ShiftView` in `prototype/index.html`).
ShiftRecord? closeShift(
  PosState s, {
  required String staffId,
  required double counted,
  DateTime? now,
}) {
  final sh = openShiftOf(s);
  if (sh == null) return null;
  final current = now ?? DateTime.now();
  sh
    ..closedAt = current.toUtc().toIso8601String()
    ..counted = counted
    ..closedBy = staffId;
  return sh;
}

/// Abstract repository contract for reading and updating [PosState].
/// Implementations MUST deep-copy [PosState] before invoking [update] mutators.
abstract class PosRepository {
  /// Current snapshot of [PosState].
  PosState get state;

  /// Stream of [PosState] updates emitted after every [update].
  Stream<PosState> get stream;

  /// Currently logged-in staff member (`null` when signed out).
  StaffMember? get currentStaff;

  /// Deep-copies the current [PosState], applies [mutator] to the copy,
  /// stores and broadcasts the new [PosState], and returns it.
  PosState update(void Function(PosState s) mutator);

  /// Updates the active session staff ID (`null` to sign out).
  void setSessionStaffId(String? staffId);
}
