import 'dart:math' as math;

import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';

export 'package:app/features/sale/presentation/bloc/sale_event.dart';

/// Immutable state for `SaleBloc`.
class SaleState extends Equatable {
  const new({
    required this.posState,
    required this.tableId,
    required this.pkgId,
    required this.timing,
    required this.a,
    required this.c,
    required this.f,
    required this.ad,
    required this.notes,
    required this.selectedCategory,
    this.step = 'order',
    this.payMethodId = 'pm1',
    this.cashReceived = '',
    this.transferStatus = 'waiting',
    this.settledBillId,
    this.toastMessage = '',
    this.now,
  });

  final PosState posState;
  final String tableId;
  final String pkgId;
  final String timing;
  final int a;
  final int c;
  final int f;
  final Map<String, int> ad;
  final String notes;
  final String selectedCategory;
  final String step;
  final String payMethodId;
  final String cashReceived;
  final String transferStatus;
  final String? settledBillId;
  final String toastMessage;
  final DateTime? now;

  DiningTable? get table =>
      posState.tables.where((t) => t.id == tableId).firstOrNull;

  OpenTableState? get openTable => posState.openTables[tableId];

  List<PackageItem> get activePackages =>
      posState.packages.where((p) => p.active).toList();

  List<AddonItem> get activeAddons =>
      posState.addons.where((x) => x.active).toList();

  List<PaymentMethod> get activePayments =>
      posState.payments.where((p) => p.active).toList();

  PaymentMethod? get activePaymentMethod =>
      activePayments.where((p) => p.id == payMethodId).firstOrNull ??
      activePayments.firstOrNull;

  PackageItem? get activePackage {
    final targetId = openTable?.packageId ?? pkgId;
    return posState.packages.where((p) => p.id == targetId).firstOrNull ??
        activePackages.firstOrNull;
  }

  String get effectiveTiming => openTable?.timing ?? timing;
  String get effectiveNotes => openTable?.notes ?? notes;

  List<String> get categories {
    final cats = <String>[if (openTable == null) 'แพ็กเกจ'];
    for (final x in activeAddons) {
      final cat = x.category.isNotEmpty ? x.category : 'เครื่องดื่ม';
      if (!cats.contains(cat)) cats.add(cat);
    }
    return cats;
  }

  String get activeCategory => categories.contains(selectedCategory)
      ? selectedCategory
      : (categories.isNotEmpty ? categories.first : '');

  TableTotals get sentTotals =>
      (openTable != null && effectiveTiming == 'after')
      ? tableTotals(openTable!)
      : TableTotals();

  TableTotals get cartTotals =>
      TableTotals(a: a, c: c, f: f, ad: Map<String, int>.from(ad));

  CalculatedOrder get cartOrder => orderOf(posState, activePackage, cartTotals);

  CalculatedOrder get payOrder => effectiveTiming == 'after'
      ? orderOf(posState, activePackage, mergeTotals(sentTotals, cartTotals))
      : cartOrder;

  List<SentLineItem> get sentRows =>
      (openTable != null && effectiveTiming == 'after')
      ? sentLines(posState, activePackage, sentTotals)
      : const <SentLineItem>[];

  double get due => openTable != null ? tableDue(posState, openTable!) : 0;

  TableTimerStatus? get timer =>
      openTable != null ? tableTimer(posState, openTable!, now: now) : null;

  bool get hasCart => !totalsEmpty(cartTotals);

  bool get canSend =>
      activePackage != null &&
      hasCart &&
      (openTable != null || (a + c + f) > 0);

  bool get canPay =>
      activePackage != null &&
      payOrder.total > 0 &&
      (openTable != null || (a + c + f) > 0);

  double get cashReceivedAmount => double.tryParse(cashReceived) ?? 0;

  double get cashChange => math.max(0, r2(cashReceivedAmount - payOrder.total));

  double get cashShortage =>
      math.max(0, r2(payOrder.total - cashReceivedAmount));

  bool get canConfirmPayment {
    final m = activePaymentMethod;
    if (m == null || !canPay || openShiftOf(posState) == null) return false;
    if (m.type == 'cash') return cashReceivedAmount >= payOrder.total;
    if (m.type == 'transfer' || m.type == 'card') {
      return transferStatus != 'failed';
    }
    return true;
  }

  BillRecord? get settledBill => settledBillId == null
      ? null
      : posState.sales.where((b) => b.id == settledBillId).firstOrNull;

  SaleState copyWith({
    PosState? posState,
    String? tableId,
    String? pkgId,
    String? timing,
    int? a,
    int? c,
    int? f,
    Map<String, int>? ad,
    String? notes,
    String? selectedCategory,
    String? step,
    String? payMethodId,
    String? cashReceived,
    String? transferStatus,
    String? settledBillId,
    bool clearSettledBill = false,
    String? toastMessage,
    DateTime? now,
  }) => SaleState(
    posState: posState ?? this.posState,
    tableId: tableId ?? this.tableId,
    pkgId: pkgId ?? this.pkgId,
    timing: timing ?? this.timing,
    a: a ?? this.a,
    c: c ?? this.c,
    f: f ?? this.f,
    ad: ad ?? this.ad,
    notes: notes ?? this.notes,
    selectedCategory: selectedCategory ?? this.selectedCategory,
    step: step ?? this.step,
    payMethodId: payMethodId ?? this.payMethodId,
    cashReceived: cashReceived ?? this.cashReceived,
    transferStatus: transferStatus ?? this.transferStatus,
    settledBillId: clearSettledBill
        ? null
        : (settledBillId ?? this.settledBillId),
    toastMessage: toastMessage ?? this.toastMessage,
    now: now ?? this.now,
  );

  @override
  List<Object?> get props => [
    posState,
    tableId,
    pkgId,
    timing,
    a,
    c,
    f,
    ad,
    notes,
    selectedCategory,
    step,
    payMethodId,
    cashReceived,
    transferStatus,
    settledBillId,
    toastMessage,
    now,
  ];
}
