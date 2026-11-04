import 'dart:async';
import 'dart:math' as math;

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
      super(_blankCartState(repository.state, initialTableId, now: now)) {
    on<SaleTableSelected>(_onTableSelected);
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
    on<SalePaymentMethodSelected>(_onPaymentMethodSelected);
    on<SaleCashReceivedChanged>(
      (e, emit) => emit(state.copyWith(cashReceived: e.value)),
    );
    on<SaleTransferStatusChanged>(
      (e, emit) => emit(state.copyWith(transferStatus: e.status)),
    );
    on<SalePaymentSubmitted>(_onPaymentSubmitted);
    on<SaleReceiptDismissed>(
      (e, emit) => emit(state.copyWith(clearSettledBill: true)),
    );
    on<SaleTableClosed>(_onTableClosed);
    on<SaleToastCleared>((e, emit) => emit(state.copyWith(toastMessage: '')));
    on<SalePosStateUpdated>(_onPosStateUpdated);

    _sub = _repository.stream.listen((_) => add(const SalePosStateUpdated()));
  }

  final PosRepository _repository;
  final DateTime? _fixedNow;
  StreamSubscription<PosState>? _sub;
  static int _billSeq = 0;

  static SaleState _blankCartState(
    PosState s,
    String tableId, {
    DateTime? now,
    String? settledBillId,
    String toastMessage = '',
  }) {
    final o = s.openTables[tableId];
    final firstPkg = s.packages.where((p) => p.active).firstOrNull;
    final pkgId = o?.packageId ?? (firstPkg?.id ?? '');
    final timing = o?.timing ?? s.shop.payTiming;
    final firstAddonCat =
        s.addons.where((x) => x.active).firstOrNull?.category ?? 'เครื่องดื่ม';
    final firstPayId =
        s.payments.where((p) => p.active).firstOrNull?.id ?? 'pm1';
    return SaleState(
      posState: s,
      tableId: tableId,
      pkgId: pkgId,
      timing: timing,
      a: o != null ? 0 : 2,
      c: 0,
      f: 0,
      ad: const <String, int>{},
      notes: '',
      selectedCategory: o != null ? firstAddonCat : 'แพ็กเกจ',
      payMethodId: firstPayId,
      settledBillId: settledBillId,
      toastMessage: toastMessage,
      now: now,
    );
  }

  void _onTableSelected(SaleTableSelected event, Emitter<SaleState> emit) {
    emit(_blankCartState(_repository.state, event.tableId, now: _fixedNow));
  }

  void _onHeadsChanged(SaleHeadsChanged event, Emitter<SaleState> emit) {
    emit(
      state.copyWith(
        a: event.a != null ? math.max(0, event.a!) : state.a,
        c: event.c != null ? math.max(0, event.c!) : state.c,
        f: event.f != null ? math.max(0, event.f!) : state.f,
      ),
    );
  }

  void _onAddonQtyChanged(SaleAddonQtyChanged event, Emitter<SaleState> emit) {
    final addon = state.posState.addons
        .where((x) => x.id == event.addonId)
        .firstOrNull;
    final maxStock = addon?.stock ?? event.qty;
    final clamped = math.min(math.max(0, event.qty), maxStock);
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
  ) {
    final cur = state.ad[event.addonId] ?? 0;
    _onAddonQtyChanged(
      SaleAddonQtyChanged(addonId: event.addonId, qty: cur + 1),
      emit,
    );
  }

  void _onNotesSaved(SaleNotesSaved event, Emitter<SaleState> emit) {
    final trimmed = event.notes.trim();
    if (state.openTable != null) {
      final nextPos = _repository.update((s) {
        s.openTables[state.tableId]?.notes = trimmed;
      });
      emit(state.copyWith(posState: nextPos, toastMessage: 'บันทึกโน้ตแล้ว'));
    } else {
      emit(state.copyWith(notes: trimmed, toastMessage: 'บันทึกโน้ตแล้ว'));
    }
  }

  void _onRoundSent(SaleRoundSent event, Emitter<SaleState> emit) {
    final tb = state.table;
    final pkg = state.activePackage;
    if (tb == null || pkg == null || !state.canSend) return;
    final cart = state.cartTotals;
    final timing = state.effectiveTiming;
    final notes = state.notes;
    final nextPos = _repository.update((s) {
      sendRound(
        s,
        tb,
        cart,
        event.staff,
        timing,
        pkg.id,
        notes,
        now: event.now ?? _fixedNow,
      );
    });
    emit(
      _blankCartState(
        nextPos,
        state.tableId,
        now: _fixedNow,
        toastMessage: 'ส่งออเดอร์โต๊ะ ${tb.name} แล้ว',
      ),
    );
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
    final nextPos = _repository.update((s) {
      adjustSent(
        s,
        state.tableId,
        event.kind,
        event.key,
        event.qty,
        event.reason.trim(),
        event.staff,
        now: event.now ?? _fixedNow,
      );
    });
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
      final totalStr = state.payOrder.total % 1 == 0
          ? state.payOrder.total.toInt().toString()
          : state.payOrder.total.toStringAsFixed(2);
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

  void _onPaymentMethodSelected(
    SalePaymentMethodSelected event,
    Emitter<SaleState> emit,
  ) {
    emit(
      state.copyWith(payMethodId: event.methodId, transferStatus: 'waiting'),
    );
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
    final cart = state.cartTotals;
    final timing = state.effectiveTiming;
    final notes = state.notes;
    final recv = method.type == 'cash'
        ? state.cashReceivedAmount
        : state.payOrder.total;

    final nextPos = _repository.update((s) {
      settle(
        s,
        tb,
        cart,
        event.staff,
        timing: timing,
        pkgId: pkg.id,
        method: method,
        received: recv,
        billId: billId,
        notes: notes,
        now: currentNow,
      );
    });

    emit(
      _blankCartState(
        nextPos,
        state.tableId,
        now: _fixedNow,
        settledBillId: billId,
      ),
    );
  }

  void _onTableClosed(SaleTableClosed event, Emitter<SaleState> emit) {
    final tb = state.table;
    if (tb == null || state.due > 0) return;
    final nextPos = _repository.update((s) {
      s.openTables.remove(state.tableId);
    });
    emit(
      _blankCartState(
        nextPos,
        state.tableId,
        now: _fixedNow,
        toastMessage: 'เก็บโต๊ะ ${tb.name} แล้ว',
      ),
    );
  }

  void _onPosStateUpdated(SalePosStateUpdated event, Emitter<SaleState> emit) {
    emit(state.copyWith(posState: _repository.state));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
