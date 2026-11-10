import 'package:app/domain/domain.dart';
import 'package:equatable/equatable.dart';

/// Base event for `SaleBloc` (`SaleView` in `prototype/index.html`).
sealed class SaleEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Switches the active table in `SaleView`.
final class SaleTableSelected extends SaleEvent {
  const new(this.tableId);
  final String tableId;
  @override
  List<Object?> get props => [tableId];
}

/// Selects a buffet package (`pkgId`).
final class SalePackageSelected extends SaleEvent {
  const new(this.packageId);
  final String packageId;
  @override
  List<Object?> get props => [packageId];
}

/// Changes the payment timing (`'before'` or `'after'`) when opening a table.
final class SaleTimingChanged extends SaleEvent {
  const new(this.timing);
  final String timing;
  @override
  List<Object?> get props => [timing];
}

/// Selects the active product/package tab (`cat`).
final class SaleCategorySelected extends SaleEvent {
  const new(this.category);
  final String category;
  @override
  List<Object?> get props => [category];
}

/// Updates adult (`a`), child (`c`), or free toddler (`f`) head counts.
final class SaleHeadsChanged extends SaleEvent {
  const new({this.a, this.c, this.f});
  final int? a;
  final int? c;
  final int? f;
  @override
  List<Object?> get props => [a, c, f];
}

/// Sets the quantity of an addon item in the current cart (`setDrink`).
final class SaleAddonQtyChanged extends SaleEvent {
  const new({required this.addonId, required this.qty});
  final String addonId;
  final int qty;
  @override
  List<Object?> get props => [addonId, qty];
}

/// Increments an addon item by 1 when tapping its `ProductCard`.
final class SaleAddonIncremented extends SaleEvent {
  const new(this.addonId);
  final String addonId;
  @override
  List<Object?> get props => [addonId];
}

/// Saves table notes (`NoteModal`).
final class SaleNotesSaved extends SaleEvent {
  const new(this.notes);
  final String notes;
  @override
  List<Object?> get props => [notes];
}

/// Sends the current cart as a round in eat-before-paying mode (`sendRound`).
final class SaleRoundSent extends SaleEvent {
  const new({required this.staff, this.now});
  final StaffMember staff;
  final DateTime? now;
  @override
  List<Object?> get props => [staff.id, now];
}

/// Reduces/removes an already-sent item (`adjustSent`). Manager/owner only.
final class SaleSentItemAdjusted extends SaleEvent {
  const new({
    required this.kind,
    required this.key,
    required this.qty,
    required this.reason,
    required this.staff,
    this.now,
  });
  final String kind;
  final String key;
  final int qty;
  final String reason;
  final StaffMember staff;
  final DateTime? now;
  @override
  List<Object?> get props => [kind, key, qty, reason, staff.id, now];
}

/// Switches between `'order'` and `'pay'` steps in `SaleOrderPanel`.
final class SalePaymentStepChanged extends SaleEvent {
  const new(this.step);
  final String step;
  @override
  List<Object?> get props => [step];
}

/// Selects a payment method (`cash`, `qr`, `transfer`, `card`).
final class SalePaymentMethodSelected extends SaleEvent {
  const new(this.methodId);
  final String methodId;
  @override
  List<Object?> get props => [methodId];
}

/// Updates the cash amount received string (`recv`).
final class SaleCashReceivedChanged extends SaleEvent {
  const new(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

/// Updates the transfer/card status (`'waiting'`, `'success'`, `'failed'`).
final class SaleTransferStatusChanged extends SaleEvent {
  const new(this.status);
  final String status;
  @override
  List<Object?> get props => [status];
}

/// Selects the target store bank account for a bank transfer (`transfer`).
final class SaleBankAccountSelected extends SaleEvent {
  const new(this.bankAccountId);
  final String bankAccountId;
  @override
  List<Object?> get props => [bankAccountId];
}

/// Toggles satang rounding (`'down'` vs `'none'`) for the current checkout.
final class SaleRoundingToggled extends SaleEvent {
  const new({required this.roundDown});
  final bool roundDown;
  @override
  List<Object?> get props => [roundDown];
}

/// Voids a settled bill (e.g. when the customer changes their mind after
/// printing the slip) and restores addon stock.
final class SaleSettledBillVoided extends SaleEvent {
  const new({required this.staff, this.billId, this.reason = ''});
  final StaffMember staff;
  final String? billId;
  final String reason;
  @override
  List<Object?> get props => [staff.id, billId, reason];
}

/// Cancels an unpaid open table (`cancelOpenTable`) when a customer changes
/// their mind before payment is finalized.
final class SaleOpenTableCancelled extends SaleEvent {
  const new();
}

/// Confirms payment and settles the bill via domain `settle(...)`.
final class SalePaymentSubmitted extends SaleEvent {
  const new({required this.staff, this.billId, this.now});
  final StaffMember staff;
  final String? billId;
  final DateTime? now;
  @override
  List<Object?> get props => [staff.id, billId, now];
}

/// Dismisses the post-payment receipt modal (`ReceiptModal`).
final class SaleReceiptDismissed extends SaleEvent {
  const new();
}

/// Closes an occupied table when `due == 0` (`เก็บโต๊ะ`).
final class SaleTableClosed extends SaleEvent {
  const new();
}

/// Clears the transient toast/error message.
final class SaleToastCleared extends SaleEvent {
  const new();
}

/// Synchronizes `SaleState` with the latest `PosRepository` state.
final class SalePosStateUpdated extends SaleEvent {
  const new();
}
