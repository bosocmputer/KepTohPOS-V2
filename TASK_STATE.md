# TASK_STATE.md

- **Branch:** `flutter/f5-bills`
- **Completed (F0 + F1 + F2 + F3 + F4a + F4b + F4c + F5 Bills, Toast Service, Full-Height Drawers & Slimmer Topbar):**
  - **Section 0 (F4c follow-up committed as `5ce5a9e`):**
    - `NumPad` delete button uses backspace icon (`⌫` / `Icons.backspace_outlined`).
    - `PaymentPicker` uses short label (`"โอนเงิน"` for `"โอนเข้าบัญชีร้าน"`) and 2-line wrapping without `"..."` truncation.
    - Cash payment `"ยังขาดอีก"` uses `r2(...)` rounding matching `cashChange`.
  - **Step F5 (`voidBill` + `BillsCubit` + `BillsPage` + `BillsFilterDrawer` + `ReceiptModal` void extension, committed as `bbdf586`):**
    - Confirmed business rule documented in `docs/llms/keptoh-blueprint.md`: voiding a bill (`voidBill()`) requires `me.role != 'cashier'`, sets `voided = true`, `voidBy = me.name`, `voidReason = reason.trim().isEmpty ? 'ไม่ระบุ' : reason.trim()`, `voidAt = nowISO()`, excludes the bill from sales totals and `computeLedger`, and automatically restores `addons` stock by the net quantities in `bill.lines` (idempotent on repeated calls).
    - Created `BillsCubit` / `BillsState` (`app/lib/features/bills/presentation/cubit/bills_cubit.dart`), `BillsPage` (`app/lib/features/bills/presentation/pages/bills_page.dart`), and `BillsFilterDrawer` (`app/lib/features/bills/presentation/widgets/bills_filter_drawer.dart`), wired into `/bills` route and topbar search in `app_router.dart` and `app.dart`.
    - Extended `ReceiptCard` and `ReceiptModal` (`app/lib/features/sale/presentation/widgets/sale_receipt_modal.dart`) with `"ยกเลิก"` stamp, `"ยกเลิกโดย ... · เหตุผล"`, and `"ยกเลิกบิล"` confirmation flow for `manager`/`owner`.
  - **Single Auto-Dismissing Toast Service (committed as `01726ec`):**
    - Created `AppToastService` (`app/lib/core/widgets/toast.dart`) using root `OverlayEntry` + `2.5s` `Timer` (tap-to-dismiss, single active toast replacement, top-center below Topbar with `SafeArea`).
    - Updated `BillsPage` and `SalePage` to show toast via `BlocListener` / `BlocConsumer` and immediately clear `toastMessage` in Cubit/Bloc; removed inline `AppToast` from `BillsPage`.
  - **Full-Height Right Drawers & Slimmer Topbar:**
    - Added `RootOverlayBox` and `RightSheetDrawer` in `app/lib/core/widgets/modal.dart` (`OverlayPortal.targetsRootOverlay` + `SafeArea`) so `BillsFilterDrawer`, `ReceiptModal`, and future right-side filter drawers span `100%` screen height with dark scrim covering the Topbar.
    - Updated `AppDimensions.topbarHeight` and `ShellHeaderBar` (`64px` at height `<= 820`, `72px` at `1366x1024`, `44px` controls/avatar, `1px` `tokens.line` bottom border) and updated all golden snapshots.
- **In Progress / Broken:** None.
- **Next Immediate Step:** Proceed to Step F6 (`/stock`, `/expenses`, `/reports`, `/setup`) per `docs/llms/flutter-plan.md`.
