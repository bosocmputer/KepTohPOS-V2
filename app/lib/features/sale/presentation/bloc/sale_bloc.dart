import 'dart:async';
import 'dart:math' as math;

import 'package:app/core/utils/formatters.dart';
import 'package:app/core/utils/sequential_events.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/bloc/sale_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/sale/presentation/bloc/sale_state.dart';

/// BLoC managing table order building, sending rounds (`sendRound`),
/// manager-only sent item adjustments (`adjustSent`), and payment settlement
/// (`settle` in `prototype/index.html`).
class SaleBloc extends Bloc<SaleEvent, SaleState> {
  new(PosRepository repository, {required String initialTableId, DateTime? now})
    : _repository = repository,
      _fixedNow = now,
      super(SaleState.blankCart(repository.state, initialTableId, now: now)) {
    on<SaleEvent>(_dispatch, transformer: sequentialEvents());

    _sub = _repository.stream.listen((_) => add(const SalePosStateUpdated()));
  }

  final PosRepository _repository;
  final DateTime? _fixedNow;
  StreamSubscription<PosState>? _sub;

  void _emitReset(
    Emitter<SaleState> emit,
    PosState pos, {
    String? settledBillId,
    String toast = '',
  }) => emit(
    SaleState.blankCart(
      pos,
      state.tableId,
      now: _fixedNow,
      settledBillId: settledBillId,
      toastMessage: toast,
    ),
  );

  /// Runs every event in one queue so async handlers cannot overlap.
  Future<void> _dispatch(SaleEvent event, Emitter<SaleState> emit) async {
    switch (event) {
      case final SaleTableSelected e:
        emit(SaleState.blankCart(_repository.state, e.tableId, now: _fixedNow));
      case final SalePackageSelected e:
        emit(state.copyWith(pkgId: e.packageId));
      case final SaleTimingChanged e:
        emit(state.copyWith(timing: e.timing));
      case final SaleCategorySelected e:
        emit(state.copyWith(selectedCategory: e.category));
      case final SaleHeadsChanged e:
        _onHeadsChanged(e, emit);
      case final SaleAddonQtyChanged e:
        _onAddonQtyChanged(e, emit);
      case final SaleAddonIncremented e:
        _onAddonIncremented(e, emit);
      case final SaleNotesSaved e:
        await _onNotesSaved(e, emit);
      case final SaleRoundSent e:
        await _onRoundSent(e, emit);
      case final SaleSentItemAdjusted e:
        await _onSentItemAdjusted(e, emit);
      case final SalePaymentStepChanged e:
        _onPaymentStepChanged(e, emit);
      case final SalePaymentMethodSelected e:
        emit(
          state.copyWith(payMethodId: e.methodId, transferStatus: 'waiting'),
        );
      case final SaleCashReceivedChanged e:
        emit(state.copyWith(cashReceived: e.value));
      case final SaleTransferStatusChanged e:
        emit(state.copyWith(transferStatus: e.status));
      case final SaleBankAccountSelected e:
        emit(state.copyWith(bankAccountId: e.bankAccountId));
      case final SalePaymentSubmitted e:
        await _onPaymentSubmitted(e, emit);
      case final SaleSettledBillVoided e:
        await _onSettledBillVoided(e, emit);
      case final SaleOpenTableCancelled e:
        await _onOpenTableCancelled(e, emit);
      case SaleReceiptDismissed():
        emit(state.copyWith(clearSettledBill: true));
      case final SaleTableClosed e:
        await _onTableClosed(e, emit);
      case SaleToastCleared():
        emit(state.copyWith(toastMessage: ''));
      case SalePosStateUpdated():
        emit(state.copyWith(posState: _repository.state));
    }
  }

  void _onHeadsChanged(SaleHeadsChanged event, Emitter<SaleState> emit) => emit(
    state.copyWith(
      a: event.a != null ? math.max(0, event.a!) : state.a,
      c: event.c != null ? math.max(0, event.c!) : state.c,
      f: event.f != null ? math.max(0, event.f!) : state.f,
    ),
  );

  void _onAddonQtyChanged(SaleAddonQtyChanged event, Emitter<SaleState> emit) {
    final addon = state.posState.addons
        .where((x) => x.id == event.addonId)
        .firstOrNull;
    final clamped = math.min(math.max(0, event.qty), addon?.stock ?? event.qty);
    final nextAd = Map<String, int>.from(state.ad);
    if (clamped > 0) {
      nextAd[event.addonId] = clamped;
    } else {
      nextAd.remove(event.addonId);
    }
    emit(state.copyWith(ad: Map<String, int>.unmodifiable(nextAd)));
  }

  void _onAddonIncremented(
    SaleAddonIncremented event,
    Emitter<SaleState> emit,
  ) => _onAddonQtyChanged(
    SaleAddonQtyChanged(
      addonId: event.addonId,
      qty: (state.ad[event.addonId] ?? 0) + 1,
    ),
    emit,
  );

  Future<void> _onNotesSaved(
    SaleNotesSaved event,
    Emitter<SaleState> emit,
  ) async {
    final trimmed = event.notes.trim();
    if (state.openTable != null) {
      final nextPos = await _repository.setTableNotes(state.tableId, trimmed);
      emit(state.copyWith(posState: nextPos, toastMessage: 'บันทึกโน้ตแล้ว'));
    } else {
      emit(state.copyWith(notes: trimmed, toastMessage: 'บันทึกโน้ตแล้ว'));
    }
  }

  Future<void> _onRoundSent(
    SaleRoundSent event,
    Emitter<SaleState> emit,
  ) async {
    final tb = state.table;
    final pkg = state.activePackage;
    if (tb == null || pkg == null || !state.canSend) return;
    final nextPos = await _repository.sendOrderRound(
      table: tb,
      cart: state.cartTotals,
      staff: event.staff,
      timing: state.effectiveTiming,
      packageId: pkg.id,
      notes: state.notes,
      now: event.now ?? _fixedNow,
    );
    _emitReset(emit, nextPos, toast: 'ส่งออเดอร์โต๊ะ ${tb.name} แล้ว');
  }

  Future<void> _onSentItemAdjusted(
    SaleSentItemAdjusted event,
    Emitter<SaleState> emit,
  ) async {
    if (event.staff.role == 'cashier') {
      emit(state.copyWith(toastMessage: 'ผู้จัดการขึ้นไปเท่านั้น'));
      return;
    }
    if (event.reason.trim().isEmpty || event.qty <= 0) return;
    final nextPos = await _repository.adjustSentItem(
      tableId: state.tableId,
      kind: event.kind,
      key: event.key,
      qty: event.qty,
      reason: event.reason.trim(),
      staff: event.staff,
      now: event.now ?? _fixedNow,
    );
    emit(state.copyWith(posState: nextPos, toastMessage: 'ลบรายการแล้ว'));
  }

  void _onPaymentStepChanged(
    SalePaymentStepChanged event,
    Emitter<SaleState> emit,
  ) {
    if (event.step == 'pay') {
      if (openShiftOf(state.posState) == null) {
        emit(state.copyWith(toastMessage: 'ต้องเปิดกะก่อนจึงรับเงินได้'));
        return;
      }
      if (!state.canPay) return;
      final totalStr = bahtInputText(state.payOrder.total);
      emit(
        state.copyWith(
          step: 'pay',
          cashReceived: state.cashReceived.isEmpty
              ? totalStr
              : state.cashReceived,
        ),
      );
    } else {
      emit(state.copyWith(step: event.step));
    }
  }

  Future<void> _onPaymentSubmitted(
    SalePaymentSubmitted event,
    Emitter<SaleState> emit,
  ) async {
    final tb = state.table;
    final pkg = state.activePackage;
    final method = state.activePaymentMethod;
    if (tb == null || pkg == null || method == null) return;
    if (!state.canConfirmPayment) {
      emit(state.copyWith(toastMessage: 'จำนวนเงินที่รับยังไม่ครบ'));
      return;
    }
    final currentNow = event.now ?? _fixedNow ?? DateTime.now();
    final billId = event.billId ?? _repository.newBillId(currentNow);
    final recv = method.type == 'cash'
        ? state.cashReceivedAmount
        : state.payOrder.total;
    final nextPos = await _repository.settleOrder(
      table: tb,
      cart: state.cartTotals,
      staff: event.staff,
      timing: state.effectiveTiming,
      packageId: pkg.id,
      method: method,
      received: recv,
      billId: billId,
      bankAccount: state.activeBankAccount,
      notes: state.notes,
      now: currentNow,
    );
    _emitReset(emit, nextPos, settledBillId: billId);
  }

  Future<void> _onSettledBillVoided(
    SaleSettledBillVoided event,
    Emitter<SaleState> emit,
  ) async {
    final targetId = event.billId ?? state.settledBillId;
    if (targetId == null) return;
    final ok = await _repository.voidSale(
      billId: targetId,
      staff: event.staff,
      allowCashier: true,
      reason: event.reason.trim().isEmpty
          ? 'ลูกค้าเปลี่ยนใจไม่รับประทาน'
          : event.reason,
      now: _fixedNow,
    );
    if (ok) {
      _emitReset(
        emit,
        _repository.state,
        toast: 'ยกเลิกบิลและคืนสถานะโต๊ะเรียบร้อย',
      );
    }
  }

  Future<void> _onOpenTableCancelled(
    SaleOpenTableCancelled event,
    Emitter<SaleState> emit,
  ) async {
    final tb = state.table;
    if (tb == null) return;
    final nextPos = await _repository.cancelTable(state.tableId);
    _emitReset(emit, nextPos, toast: 'ยกเลิกรายการโต๊ะ ${tb.name} เรียบร้อย');
  }

  Future<void> _onTableClosed(
    SaleTableClosed event,
    Emitter<SaleState> emit,
  ) async {
    final tb = state.table;
    if (tb == null || state.due > 0) return;
    final nextPos = await _repository.closeTable(state.tableId);
    _emitReset(emit, nextPos, toast: 'เก็บโต๊ะ ${tb.name} แล้ว');
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
