# TASK_STATE.md

- **Branch:** `flutter/f6-stock`
- **Completed (F0 + F1 + F2 + F3 + F4a + F4b + F4c + F5 + F6 Stock):**
  - **Section 0 (`66b4a7e`):**
    - Updated `.gitignore` (`.serena/`, `.vscode/`, `.DS_Store`) and committed `app/devtools_options.yaml`.
    - Fixed sent-line icons in `SaleOrderPanel` (`app/lib/features/sale/presentation/widgets/sale_order_panel.dart`) via `AppIcons.forLineKind` so head lines (`ผู้ใหญ่/เด็ก/เด็กเล็ก`) use `'user'` instead of `'drink'`.
  - **Section 1 — Step F6 Stock (`feat(stock): fast daily count, purchases, expenses and balance`):**
    - Confirmed stock rules documented in `docs/llms/keptoh-blueprint.md`:
      1. `StockStatus`: `out` (`qty <= 0`), `low` (`par > 0 && 0 < qty < par`, recommended order `roundQty(par - qty, unit)`), `ok` (`qty >= par`, or `qty > 0` when `par <= 0`).
      2. Units & rounding: discrete units (`kCountUnits`: `ฟอง, แพ็ค, ถุง, ชิ้น, ขวด`) disable `.` on `NumPad`; continuous units (`กก., ลิตร`) allow `.` up to 1 decimal place (`maxDecimalPlaces: 1`); saving rounds with `roundQty(val, unit)`.
      3. Costing: `savePurchase` never mutates `ing.lastCost`; all unit costs come from `st.purchases` via `computeLedger`, and `StockBalance` switches between `ต้นทุนเฉลี่ย` (`avg`) and `ราคาซื้อล่าสุด` (`last`) per `shop.costMethod`.
      4. Permissions: `cashier` can add purchases and daily expenses; editing/deleting purchases or daily expenses and reopening a closed day (`ยกเลิกการปิดวัน`) are restricted to `manager`/`owner`.
    - Implemented domain operations in `app/lib/domain/stock_ops.dart` and updated `app/lib/domain/ledger.dart`.
    - Implemented `StockCountBloc` (`app/lib/features/stock/presentation/bloc/`) and `StockCubit` (`app/lib/features/stock/presentation/cubit/`), scoped to `/stock` route in `app/lib/core/router/app_router.dart` (created fresh on entering `/stock`, never held at app root).
    - Built `StockPage`, `StockCountTab`, `StockCountNumPadPanel`, `StockPurchaseTab`, `PurchaseModal`, `StockExpenseTab`, `ExpenseModal`, `StockBalanceTab`, and `StockFilterDrawer` (reusing shared `RightSheetDrawer` and `AppToastService`).
    - Added JS parity unit tests (`stock_ops_test.dart`), BLoC tests (`stock_bloc_test.dart`), widget flow tests (`stock_flow_test.dart`), and golden tests (`stock_golden_test.dart` at `1024x768` and `1366x1024`).
    - Polished `/stock` UI based on iPad `1024x768` screen audit: removed `"แสดงทุกรายการ"` toggle so all 15 ingredients are always displayed in `StockCountTab`, tightened `StockCountNumPadPanel` spacing, fixed `Field` empty-label height & `Dropdown` compact height in `PurchaseModal` / `ExpenseModal`, aligned `Modal` footer totals to the left via `footerLeading`, aligned `StockExpenseTab` footer total under the `ยอด` column, and expanded `Seg` full-width in `StockFilterDrawer`.
- **In Progress / Broken:** None.
- **Next Immediate Step:** Proceed to Step F7 (`/dashboard`, `/reports`, `/setup`) per `docs/llms/flutter-plan.md`.
