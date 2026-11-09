import 'dart:async';

import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:app/features/bills/presentation/cubit/bills_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/bills/presentation/cubit/bills_state.dart';

/// Cubit managing daily sales bills, filters, pagination, and voiding.
class BillsCubit extends Cubit<BillsState> {
  new(PosRepository repository, {DateTime? now, String? initialDate})
    : _repository = repository,
      _fixedNow = now,
      super(
        _initialState(repository.state, now: now, initialDate: initialDate),
      ) {
    _sub = _repository.stream.listen((s) {
      if (!isClosed) emit(state.copyWith(posState: s));
    });
  }

  final PosRepository _repository;
  final DateTime? _fixedNow;
  StreamSubscription<PosState>? _sub;

  static BillsState _initialState(
    PosState s, {
    DateTime? now,
    String? initialDate,
  }) {
    final tk = businessDayKey(now ?? DateTime.now(), s.shop.dayCutoffMinutes);
    return BillsState(
      posState: s,
      selectedDate: initialDate ?? tk,
      todayDate: tk,
      now: now,
    );
  }

  void setDate(String date) {
    emit(
      state.copyWith(
        selectedDate: date,
        page: 1,
        olderBills: const <BillRecord>[],
        olderFailed: false,
      ),
    );
    if (state.isOlderDay) unawaited(_loadOlder(date));
  }

  Future<void> _loadOlder(String date) async {
    try {
      final bills = await _repository.billsForDay(date);
      if (!isClosed && state.selectedDate == date) {
        emit(state.copyWith(olderBills: bills, olderFailed: false));
      }
    } on Object {
      if (!isClosed && state.selectedDate == date) {
        emit(state.copyWith(olderFailed: true));
      }
    }
  }

  void setSearchQuery(String query) =>
      emit(state.copyWith(searchQuery: query, page: 1));

  void toggleMethodFilter(String methodId) {
    final next = Set<String>.from(state.selectedMethodIds);
    if (!next.remove(methodId)) next.add(methodId);
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
  Future<bool> voidBillById({
    required StaffMember staff,
    String? billId,
    String reason = '',
  }) async {
    final targetId = billId ?? state.selectedBillId;
    if (targetId == null || staff.role == 'cashier') return false;
    final bill = [
      ..._repository.state.sales,
      ...state.olderBills,
    ].where((b) => b.id == targetId).firstOrNull;
    if (bill == null || bill.voided) return false;
    final billNo = bill.no;
    final bool ok;
    try {
      ok = await _repository.voidSale(
        billId: targetId,
        staff: staff,
        reason: reason,
        now: _fixedNow ?? state.now,
      );
    } on PosCommandException catch (e) {
      emit(state.copyWith(toastMessage: e.message));
      return false;
    }
    if (ok) {
      if (state.isOlderDay) await _loadOlder(state.selectedDate);
      emit(
        state.copyWith(
          posState: _repository.state,
          toastMessage: 'ยกเลิกบิล $billNo แล้ว',
        ),
      );
    }
    return ok;
  }

  /// Voids [billId] and issues a replacement, then opens the new bill.
  /// Failures (incl. offline) propagate as [PosCommandException].
  Future<void> reissueBill({
    required String billId,
    required String reason,
    String? methodId,
    String? bankAccountId,
  }) async {
    final created = await _repository.reissueBill(
      billId: billId,
      reason: reason,
      methodId: methodId,
      bankAccountId: bankAccountId,
    );
    if (isClosed) return;
    if (state.isOlderDay) await _loadOlder(state.selectedDate);
    if (isClosed) return;
    emit(
      state.copyWith(
        posState: _repository.state,
        selectedBillId: created.id,
        toastMessage: 'ออกใบใหม่แทนแล้ว ${created.no}',
      ),
    );
  }

  /// Converts [billId] into a full tax invoice and opens the new bill.
  /// Failures (incl. offline) propagate as [PosCommandException].
  Future<void> issueFullInvoice({
    required String billId,
    required String buyerName,
    required String buyerAddress,
    String? buyerTaxId,
    String? buyerBranch,
  }) async {
    final created = await _repository.issueFullInvoice(
      billId: billId,
      buyerName: buyerName,
      buyerAddress: buyerAddress,
      buyerTaxId: buyerTaxId,
      buyerBranch: buyerBranch,
    );
    if (isClosed) return;
    if (state.isOlderDay) await _loadOlder(state.selectedDate);
    if (isClosed) return;
    emit(
      state.copyWith(
        posState: _repository.state,
        selectedBillId: created.id,
        toastMessage: 'ออกใบกำกับเต็มรูปแล้ว ${created.no}',
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
