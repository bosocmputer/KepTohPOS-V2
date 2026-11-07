import 'dart:async';
import 'dart:math' as math;

import 'package:app/core/utils/formatters.dart';
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
    on<SaleTableSelected>(
      (e, emit) => emit(
        SaleState.blankCart(_repository.state, e.tableId, now: _fixedNow),
      ),
    );
    on<SalePackageSelected>(
      (e, emit) => emit(state.copyWith(pkgId: e.packageId)),
    );
    on<SaleTimingChanged>((e, emit) => emit(state.copyWith(timing: e.timing)));
    on<SaleCategorySelected>(
      (e, emit) => emit(state.copyWith(selectedCategory: e.category)),
    );
    on<SaleHeadsChanged>(_onHeadsChanged);
    on<SaleAddonQtyChanged>(_onAddonQtyChanged);
    on<SaleAddonIncremented>(_onAddonIncremented);
    on<SaleNotesSaved>(_onNotesSaved);
    on<SaleRoundSent>(_onRoundSent);
    on<SaleSentItemAdjusted>(_onSentItemAdjusted);
    on<SalePaymentStepChanged>(_onPaymentStepChanged);
    on<SalePaymentMethodSelected>(
      (e, emit) => emit(
        state.copyWith(payMethodId: e.methodId, transferStatus: 'waiting'),
      ),
    );
    on<SaleCashReceivedChanged>(
      (e, emit) => emit(state.copyWith(cashReceived: e.value)),
    );
    on<SaleTransferStatusChanged>(
      (e, emit) => emit(state.copyWith(transferStatus: e.status)),
    );
    on<SaleBankAccountSelected>(
      (e, emit) => emit(state.copyWith(bankAccountId: e.bankAccountId)),
    );
    on<SalePaymentSubmitted>(_onPaymentSubmitted);
    on<SaleSettledBillVoided>(_onSettledBillVoided);
    on<SaleOpenTableCancelled>(_onOpenTableCancelled);
    on<SaleReceiptDismissed>(
      (e, emit) => emit(state.copyWith(clearSettledBill: true)),
    );
    on<SaleTableClosed>(_onTableClosed);
    on<SaleToastCleared>((e, emit) => emit(state.copyWith(toastMessage: '')));
    on<SalePosStateUpdated>(
      (e, emit) => emit(state.copyWith(posState: _repository.state)),
    );

    _sub = _repository.stream.listen((_) => add(const SalePosStateUpdated()));
  }

  final PosRepository _repository;
  final DateTime? _fixedNow;
  StreamSubscription<PosState>? _sub;
  static int _billSeq = 0;

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

  void _onNotesSaved(SaleNotesSaved event, Emitter<SaleState> emit) {
    final trimmed = event.notes.trim();
    if (state.openTable != null) {
      final nextPos = _repository.update(
        (s) => s.openTables[state.tableId]?.notes = trimmed,
      );
      emit(state.copyWith(posState: nextPos, toastMessage: 'บันทึกโน้ตแล้ว'));
    } else {
      emit(state.copyWith(notes: trimmed, toastMessage: 'บันทึกโน้ตแล้ว'));
    }
  }

  void _onRoundSent(SaleRoundSent event, Emitter<SaleState> emit) {
    final tb = state.table;
    final pkg = state.activePackage;
    if (tb == null || pkg == null || !state.canSend) return;
    final nextPos = _repository.update(
      (s) => sendRound(
        s,
        tb,
        state.cartTotals,
        event.staff,
        state.effectiveTiming,
        pkg.id,
        state.notes,
        now: event.now ?? _fixedNow,
      ),
    );
    _emitReset(emit, nextPos, toast: 'ส่งออเดอร์โต๊ะ ${tb.name} แล้ว');
  }

  void _onSentItemAdjusted(
    SaleSentItemAdjusted event,
    Emitter<SaleState> emit,
  ) {
    if (event.staff.role == 'cashier') {
      emit(state.copyWith(toastMessage: 'ผู้จัดการขึ้นไปเท่านั้น'));
      return;
    }
    if (event.reason.trim().isEmpty || event.qty <= 0) return;
    final nextPos = _repository.update(
      (s) => adjustSent(
        s,
        state.tableId,
        event.kind,
        event.key,
        event.qty,
        event.reason.trim(),
        event.staff,
        now: event.now ?? _fixedNow,
      ),
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

  void _onPaymentSubmitted(
    SalePaymentSubmitted event,
    Emitter<SaleState> emit,
  ) {
    final tb = state.table;
    final pkg = state.activePackage;
    final method = state.activePaymentMethod;
    if (tb == null || pkg == null || method == null) return;
    if (!state.canConfirmPayment) {
      emit(state.copyWith(toastMessage: 'จำนวนเงินที่รับยังไม่ครบ'));
      return;
    }
    final currentNow = event.now ?? _fixedNow ?? DateTime.now();
    _billSeq = (_billSeq + 1) & 0xFFFFF;
    final billId =
        event.billId ??
        'b${currentNow.millisecondsSinceEpoch.toRadixString(36)}$_billSeq';
    final recv = method.type == 'cash'
        ? state.cashReceivedAmount
        : state.payOrder.total;
    final nextPos = _repository.update(
      (s) => settle(
        s,
        tb,
        state.cartTotals,
        event.staff,
        timing: state.effectiveTiming,
        pkgId: pkg.id,
        method: method,
        received: recv,
        billId: billId,
        bankAccount: state.activeBankAccount,
        notes: state.notes,
        now: currentNow,
      ),
    );
    _emitReset(emit, nextPos, settledBillId: billId);
  }

  void _onSettledBillVoided(
    SaleSettledBillVoided event,
    Emitter<SaleState> emit,
  ) {
    final targetId = event.billId ?? state.settledBillId;
    if (targetId == null) return;
    var ok = false;
    final nextPos = _repository.update(
      (s) => ok = voidBill(
        s,
        billId: targetId,
        me: event.staff,
        allowCashier: true,
        reason: event.reason.trim().isEmpty
            ? 'ลูกค้าเปลี่ยนใจไม่รับประทาน'
            : event.reason,
        now: _fixedNow,
      ),
    );
    if (ok) {
      _emitReset(emit, nextPos, toast: 'ยกเลิกบิลและคืนสถานะโต๊ะเรียบร้อย');
    }
  }

  void _onOpenTableCancelled(
    SaleOpenTableCancelled event,
    Emitter<SaleState> emit,
  ) {
    final tb = state.table;
    if (tb == null) return;
    final nextPos = _repository.update(
      (s) => cancelOpenTable(s, state.tableId),
    );
    _emitReset(emit, nextPos, toast: 'ยกเลิกรายการโต๊ะ ${tb.name} เรียบร้อย');
  }

  void _onTableClosed(SaleTableClosed event, Emitter<SaleState> emit) {
    final tb = state.table;
    if (tb == null || state.due > 0) return;
    final nextPos = _repository.update(
      (s) => s.openTables.remove(state.tableId),
    );
    _emitReset(emit, nextPos, toast: 'เก็บโต๊ะ ${tb.name} แล้ว');
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
