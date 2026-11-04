# TASK_STATE.md

- **Branch:** `flutter/f5-bills`
- **Completed (F0 + F1 + F2 + F3 + F4a + F4b + F4c + F5 Bills & Void with Stock Return):**
  - **Section 0 (F4c follow-up committed as `5ce5a9e`):**
    - `NumPad` delete button uses backspace icon (`⌫` / `Icons.backspace_outlined`).
    - `PaymentPicker` uses short label (`"โอนเงิน"` for `"โอนเข้าบัญชีร้าน"`) and 2-line wrapping without `"..."` truncation.
    - Cash payment `"ยังขาดอีก"` uses `r2(...)` rounding matching `cashChange`.
  - **Step F5 (`voidBill` + `BillsCubit` + `BillsPage` + `BillsFilterDrawer` + `ReceiptModal` void extension):**
    - Confirmed business rule documented in `docs/llms/keptoh-blueprint.md`: voiding a bill (`voidBill()`) requires `me.role != 'cashier'`, sets `voided = true`, `voidBy = me.name`, `voidReason = reason.trim().isEmpty ? 'ไม่ระบุ' : reason.trim()`, `voidAt = nowISO()`, excludes the bill from sales totals and `computeLedger`, and automatically restores `addons` stock by the net quantities in `bill.lines` (idempotent on repeated calls).
    - Created `BillsCubit` / `BillsState` (`app/lib/features/bills/presentation/cubit/bills_cubit.dart`), `BillsPage` (`app/lib/features/bills/presentation/pages/bills_page.dart`), and `BillsFilterDrawer` (`app/lib/features/bills/presentation/widgets/bills_filter_drawer.dart`), wired into `/bills` route and topbar search in `app_router.dart` and `app.dart`.
    - Extended `ReceiptCard` and `ReceiptModal` (`app/lib/features/sale/presentation/widgets/sale_receipt_modal.dart`) with `"ยกเลิก"` stamp, `"ยกเลิกโดย ... · เหตุผล"`, and `"ยกเลิกบิล"` confirmation flow for `manager`/`owner`.
    - Added Unit, Bloc, Widget, and Golden tests (`1024x768` + `1366x1024`) for `/bills`, filter drawer, and voided receipt modal.
- **In Progress / Broken:** None.
- **Next Immediate Step:** Proceed to Step F6 (`/stock`, `/expenses`, `/reports`, `/setup`) per `docs/llms/flutter-plan.md`.
