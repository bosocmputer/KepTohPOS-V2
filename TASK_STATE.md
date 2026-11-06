# TASK_STATE.md — Detailed Audit & Handoff State for Claude Code Review

## 1. Branch & Commit Timeline (Ready for Post-Reset Audit)
- **Active Branch:** `main` (pushed to `origin/main` and deployed live on Vercel `keptohpos-v2-prototype.vercel.app`)
- **Feature Branches Available for Inspection (`git log` / `git diff`):**
  1. `flutter/f7-dashboard-reports` (`657800a`, merged into `main` at `f605091`):
     - **Step F7 (`/dashboard` & `/reports`):** `computeDashboardSummary`, `computeMonthlyReport`, `DashboardCubit`, `ReportsCubit`, `DashboardPage`, `ProfitChart` (`CustomPainter`), `ReportsPage`, `DailyReportTable`.
  2. `flutter/ui-polish` (`673b09d` -> `2950035` -> `9955619` -> `9b456ab`, merged into `main` at `bfbfd7b`):
     - **`673b09d` — Step F8 (`/setup`) + UI Polish + 3-Day Simulation:**
       - Implemented `/setup` across 4 logical groups in `app/lib/domain/setup_ops.dart`, `SetupCubit`, `SetupPage`, CRUD modals, `CrudSectionShell`, and `AppSwitch`.
       - Added pure domain simulation helpers in `app/lib/domain/demo_sim_ops.dart` (`clearDailyTransactionsInState`, `advanceSimulationDayInState`) + 3-Day Simulation tests (`three_day_simulation_test.dart`, `three_day_ui_flow_test.dart`).
     - **`9955619` — UI Theme Audit + Formal Thai Copy + 5 User Feedback Features + Accountant Controls (`A1`–`A6`):**
       - **Theme & UI Alignment Audit:**
         - Added 5 selectable brand palettes (`AppBrandPalette`: `orange`, `emerald`, `indigo`, `rose`, `slate`) in `app/lib/core/theme/tokens.dart` & `raw_tokens.dart`, persisted in `ShopConfig.themePalette` and selectable in `/setup` (`ธีมและการแสดงผล`) and `/dev/components`.
         - Fixed active navigation tab contrast in `SetupNavSidebar` (`t.onPrimary` instead of `t.primaryInk` on `t.primary` fill).
         - Fixed `Seg` active pill color to support `SegTone.brand` (`t.primary` / `t.onPrimary`) and `SegTone.neutral` (`t.ink` / `t.surface`).
         - Unified single-line `Field` (`SizedBox(height: AppDimensions.controlHeight)` = `44px`, `TextAlignVertical.center`, `isDense: true`) and `Dropdown` (`44px`) heights and vertical text centering in `app/lib/core/widgets/field.dart` and `dropdown.dart`.
         - Fixed `RenderFlex overflow` in `CrudSectionShell` (`actionColWidth: 108`) and `DataTableSimple` (`overflow: TextOverflow.ellipsis`).
         - Standardized formal Thai copy across `/login`, `/tables`, `/sale`, `/bills`, `/stock`, `/shift`, `/dashboard`, `/reports`, and `/setup`.
       - **5 User Feedback Features + 6 Accountant Controls (`A1`–`A6`):**
         1. **โอนเงินหลายบัญชีธนาคาร (`Feature 1` + `A4` + `A6`):** Added `BankAccountItem` & `kDefaultBankAccounts` (`store_entities.dart`, `shop_config.dart`), CRUD table & modal in `/setup` (`ช่องทางชำระเงิน` — `setup_finance_catalog_panels.dart`, `setup_secondary_modals.dart`), relational delete guard in `checkSetupDeleteGuard` (`setup_ops.dart` — `A6`), full-width `BankAccountPicker` in `SalePaymentPanel` (`sale_summary_widgets.dart`, `sale_payment_panel.dart`) with `กำลังรอ/สำเร็จ/ล้มเหลว` removed per user request, and per-bank-account transfer breakdown in `/bills` (`bills_cubit.dart`, `bills_page.dart` — `A4`).
         2. **พิมพ์ QR พร้อมเพย์ระบุยอดบนใบเสร็จ + ยกเลิกเมื่อลูกค้าเปลี่ยนใจหลังพิมพ์สลิป (`Feature 2` + `A2`):** Embedded EMVCo PromptPay QR (`promptPayPayload(shop.promptpay, bill.total)`) on `ReceiptCard` (`receipt-qr-box` in `receipt_card.dart`), distinct header `'ใบแจ้งยอดค่าอาหาร (ยังไม่ได้ชำระเงิน)'` vs `'ใบเสร็จรับเงิน/ใบกำกับภาษีอย่างย่อ'` (`A2`), and cashier-accessible cancellation in `ReceiptModal` (`sale_receipt_modal.dart`): `cancelOpenTable` for unpaid `after` tables and `voidBill(..., allowCashier: true)` (auto-releasing `openTables[tableId]`) for settled `before` bills (`settle.dart`, `domain.dart`).
         3. **กำหนดอัตราภาษีมูลค่าเพิ่มได้ ค่าเริ่มต้น 7% (`Feature 3` + `A1` + `A3` + `A5`):** Added `ShopConfig.vatRate` (default `7.0`), updated `calcOrder` (`order_calc.dart`), snapshotted `vatMode` & `vatRate` onto `BillRecord` at settlement (`makeBill` in `settle.dart` — `A1`), displayed `มูลค่าก่อนภาษี` + `VAT X%` on `OrderSummary`, `ReceiptCard`, `SetupShopPanel` preview (`A5`), and `BillsPage` summary (`BillsState.totalVat` & `totalPreVat` — `A3`).
         4. **กำหนดประเภทภาษี แยกนอก / รวมใน / ไม่คิดภาษี (`Feature 4`):** Updated `kVatModes` (`roles.dart`) and `SetupShopPanel` (`setup_shop_costing_panels.dart`) with `setup-vat-rate-input`.
         5. **กดดูสลิป POS ได้ทันทีในโต๊ะที่มีลูกค้า (`Feature 5`):** Added `buildTablePosSlip` (`domain.dart`) and `"สลิป POS"` / `"ดูสลิป POS"` buttons on occupied tables in `TablesPage` (`table-slip-btn-${table.id}` in `table_card.dart`) and `SalePage` (`topbar-pos-slip-btn`, `banner-pos-slip-btn`, `order-panel-pos-slip-btn`).
     - **`9b456ab` — Production Test Store Data (`จ่าโบ้หมูกะทะ`), Clean Daily State & Vercel Web Build:**
       - Updated `app/assets/mock/shop.json` & `store_entities.dart` to store `จ่าโบ้หมูกะทะ` (`95/7 Faham , Muang Chiang Mai, Chiang Mai, Thailand, Chiang Mai`, phone `082 929 5566`).
       - Updated `app/assets/mock/staff.json` to `อัย` (`owner`, PIN `1234`), `ไอติม` (`manager`, PIN `2222`), `เนส` (`cashier`, PIN `1111`).
       - Updated `MockPosRepository.loadFromAssets` (`seedTransactions: false` by default) so the app starts with 0 daily bills/transactions while preserving all master catalogs (`packages`, `addons`, `suppliers`, `ingredients`, `tables`, `staff`, `payments`, `expenseTypes`, `fixedCosts`).
       - Added `app/vercel.json`, `vercel.json`, `app/scripts/vercel-build.sh`, `scripts/vercel-build.sh`, and `app/web/vercel.json` for Vercel Flutter Web deployment (`Root Directory: app`).

## 2. Verification & Code Quality Status
- **Static Analysis:** `cd app && flutter analyze --no-pub lib test` -> `No issues found!`
- **Unit & Widget Tests:** `cd app && flutter test --no-pub test/unit test/widget` -> All 61 unit & widget test suites pass (`Exit Code: 0`).
- **300-Line Ceiling:** Every `.dart` file in `app/lib/**/*.dart` is strictly `<= 300` lines (`max = 300` lines).
- **Web Build:** `cd app && flutter build web --release --no-pub` -> `✓ Built build/web` (deployed on Vercel).
- **In Progress / Broken:** None.
- **Next Immediate Step for Claude Review:** Run `git diff f605091..bfbfd7b` to review all F8, UI/Theme polish, 5 user feedback features, accountant controls (`A1`–`A6`), and store configuration changes; optionally run `cd app && flutter test --update-goldens test/golden` if golden PNG snapshots need to be regenerated for the new store name and UI updates.
