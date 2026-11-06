# TASK_STATE.md — Detailed Audit & Handoff State for Claude Code Review

## 1. Branch & Commit Timeline (Ready for Post-Reset Audit)
- **Active Branch:** `flutter/accounting-round2` (branched from `main` at `68fe01f`)
- **Feature Branches Available for Inspection (`git log` / `git diff`):**
  1. `flutter/f7-dashboard-reports` (`657800a`, merged into `main` at `f605091`):
     - **Step F7 (`/dashboard` & `/reports`):** `computeDashboardSummary`, `computeMonthlyReport`, `DashboardCubit`, `ReportsCubit`, `DashboardPage`, `ProfitChart` (`CustomPainter`), `ReportsPage`, `DailyReportTable`.
  2. `flutter/ui-polish` (`673b09d` -> `2950035` -> `9955619` -> `9b456ab`, merged into `main` at `bfbfd7b`):
     - **`673b09d` — Step F8 (`/setup`) + UI Polish + 3-Day Simulation:**
       - Implemented `/setup` across 4 logical groups in `app/lib/domain/setup_ops.dart`, `SetupCubit`, `SetupPage`, CRUD modals, `CrudSectionShell`, and `AppSwitch`.
       - Added pure domain simulation helpers in `app/lib/domain/demo_sim_ops.dart` (`clearDailyTransactionsInState`, `advanceSimulationDayInState`) + 3-Day Simulation tests (`three_day_simulation_test.dart`, `three_day_ui_flow_test.dart`).
     - **`9955619` — UI Theme Audit + Formal Thai Copy + 5 User Feedback Features + Accountant Controls (`A1`–`A6`):**
       - Added 5 selectable brand palettes (`AppBrandPalette`), CRUD bank accounts (`BankAccountItem`), PromptPay QR on `ReceiptCard`, configurable VAT rate & mode (`vatMode`, `vatRate` snapshotted onto `BillRecord`), and POS slip button on occupied tables.
     - **`9b456ab` — Production Test Store Data (`จ่าโบ้หมูกะทะ`), Clean Daily State & Vercel Web Build:**
       - Store `จ่าโบ้หมูกะทะ`, staff `อัย`/`ไอติม`/`เนส`, clean initial daily state (`seedTransactions: false`), and Vercel build scripts (`app/vercel.json`, `app/scripts/vercel-build.sh`).
  3. `flutter/accounting-round2` (`9236896` -> `88243f2` -> `85429b5` -> `558f745` -> `2bb2502`):
     - **`9236896` — `feat(ledger): business-day cutoff for after-midnight sales` (B1):**
       - Added `kDayCutoffs` and `businessDayKey(DateTime local, [int cutoffMinutes = 0])` in `app/lib/domain/roles.dart`.
       - Added `ShopConfig.dayCutoffMinutes` (`default = 0` for JS parity; `"dayCutoffMinutes": 300` = `05:00` in `app/assets/mock/shop.json`).
       - Updated `makeBill` (`settle.dart`), `buildTablePosSlip` (`domain.dart`), `clearDailyTransactionsInState` (`demo_sim_ops.dart`), `computeLedger` (`ledger.dart`), and all date-keyed cubits/blocs (`AuthCubit`, `DashboardCubit`, `ReportsCubit`, `BillsCubit`, `TablesCubit`, `StockCubit`, `StockCountBloc`) to group after-midnight sales into the active business day while displaying the true calendar timestamp (`DateTime.parse(bill.at).toLocal()`) on `ReceiptCard`.
       - Added `setup-day-cutoff-dropdown` in `app/lib/features/setup/presentation/widgets/setup_shop_costing_panels.dart`.
     - **`88243f2` — `feat(ledger): calendar or custom fixed-cost divisor with monthly deducted vs full` (Item 3 + B3):**
       - Added `ShopConfig.fixedCostDivisor` (`'calendar' | 'custom'`, set to `'calendar'` in `MockPosRepository.loadFromAssets` when `!seedTransactions`).
       - Updated `computeLedger` (`ledger.dart`) with `fixedPerDayFor(DateTime d)` dividing `activeFixedSum` by `DateTime(d.year, d.month + 1, 0).day` (`28`/`29`/`30`/`31`) when `'calendar'` or `openDaysPerMonth` when `'custom'`.
       - Added `fixedDeducted`, `fixedFullMonth`, and `salesDays` to `MonthlyReportSummary` (`reports_ops.dart`) and `DashboardSummary` (`dashboard_reports_ops.dart`).
       - Added `setup-fixed-divisor-seg` in `setup_costing_demo_panels.dart`, and rendered `reports-partial-fixed-pill` (`"หักค่าคงที่ยังไม่ครบเดือน"`) + `"ค่าคงที่หักแล้ว ฿... จาก ฿... · ขาย ... วัน"` in `reports_page.dart` and `dashboard_page.dart`.
     - **`85429b5` — `feat(receipt): eat-until time and overtime display` (Item 2 + B5):**
       - Added `eatUntil` (`String?`) and `timeLimitMin` (`int`) to `BillRecord` (`record_models.dart`).
       - Added `eatUntilOf`, `billTimerSnapshot`, and `formatTimeLimitLabel` in `order_calc.dart` using `s.openTables[tableId]?.openedAt` so customers joining later share the table's original deadline.
       - Rendered `receipt-eat-until` (`"ทานได้ถึงเวลา HH:MM น. (จำกัด ...)"` / `"ไม่จำกัดเวลา"`) on `receipt_card.dart`, `table-overtime-${table.id}` (`"เกินเวลา X น."`) on `table_card.dart`, and preset buttons (`pkg-timelimit-preset-0/90/120/180`) in `setup_crud_modals.dart`.
     - **`558f745` — `feat(sale): table summary slip across sub-bills` (Item 1 + B2):**
       - Added `TableSummarySlip` and `buildTableSummarySlip` in `app/lib/domain/table_summary.dart` collecting all bills (including voided sub-bills) created since `openTables[tableId].openedAt`.
       - Added `TableSummaryCard` (`table_summary_card.dart`) and `TableSummaryModal` (`table_summary_modal.dart`) with tabs for `สรุปทั้งโต๊ะ` and each `บิล #1..#N`, strikethrough + `"ยกเลิก"` pill on voided sub-bills (`summary-bill-voided-${b.id}`), and sub-bill voiding without closing the table while other active sub-bills remain.
       - Wired `ReceiptModal` (`sale_receipt_modal.dart`), `TablesPage`, and `SalePage` to open `TableSummaryModal` when an open table has `>= 2` bills in its session.
     - **`2bb2502` — `feat(receipt): copy watermark for reprinted receipts` (B4):**
       - Added `isCopy` to `ReceiptCard` (`receipt_card.dart`) and `ReceiptModal` (`sale_receipt_modal.dart`), rendering `receipt-copy-badge` (`"สำเนา"`) on any receipt re-opened from `/bills`, POS slip buttons, or `TableSummaryModal` sub-bill tabs while keeping immediate post-settlement receipts (`fresh: true`) and `isSlipPreview` QR slips unmarked.
       - Added unit tests in `app/test/unit/business_day_test.dart` and widget tests in `app/test/widget/accounting_round2_widget_test.dart`.

## 2. Verification & Code Quality Status
- **Static Analysis:** `cd app && flutter analyze --no-pub lib test` -> `No issues found!`
- **Unit & Widget Tests:** `cd app && flutter test --no-pub test/unit test/widget` -> All 70 unit & widget test suites pass (`Exit Code: 0`).
- **300-Line Ceiling:** Every `.dart` file in `app/lib/**/*.dart` is strictly `<= 300` lines (`max = 300` lines).
- **Web Build:** `cd app && flutter build web --release --no-pub` -> `✓ Built build/web`.
- **In Progress / Broken:** None.
- **Next Immediate Step:** Review branch `flutter/accounting-round2` (`git diff main..flutter/accounting-round2`) or merge `flutter/accounting-round2` into `main` to deploy to Vercel production.
