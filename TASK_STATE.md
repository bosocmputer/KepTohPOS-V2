# TASK_STATE.md

- **Branch:** `flutter/f7-dashboard-reports`
- **Completed (F0 + F1 + F2 + F3 + F4a + F4b + F4c + F5 + F6 + F7 Dashboard & Reports):**
  - **Step F6 Stock (`origin/main` `3cbfea6`):**
    - Completed fast daily count, purchases, expenses, stock balance, iPad `1024x768` polish, strict clock injection in `computeLedger`, and `<= 300` line limit across `app/lib`.
  - **Step F7 Dashboard & Reports (`feat(dashboard): profit overview, chart and daily reports`):**
    - Implemented pure domain calculations in `app/lib/domain/dashboard_reports_ops.dart` and `app/lib/domain/reports_ops.dart` (`computeDashboardSummary`, `computeMonthlyReport`, `IngredientCostShareRow`, `AddonSalesSummaryRow`, `DashboardSummary`, `MonthlyReportSummary`) with 100% parity against `prototype/index.html` (`DashboardView`, `ProfitChart`, `ReportsView`).
    - Implemented route-scoped `DashboardCubit` (`app/lib/features/dashboard/presentation/cubit/dashboard_cubit.dart`) and `ReportsCubit` (`app/lib/features/reports/presentation/cubit/reports_cubit.dart`), created fresh when entering `/dashboard` and `/reports` with `{DateTime? now, DateTime Function()? clock}` injection.
    - Built `DashboardPage`, `DashboardHeroSection` (`today-hero` + `PendingBadge` + `"วันนี้ยังไม่ปิดยอด"` banner with `"ไปนับของเหลือ"` button navigating to `/stock`), primary/secondary `StatsGroup`, `ProfitChart` (`CustomPainter` bar chart with 3 dashed grid lines + numbers, zero line, positive green / negative red / unclosed faint bars, `<= 10` date labels, and tap-to-inspect bar badge), and `DashboardBreakdownGrid` (`ต้นทุนวัตถุดิบแยกรายการ` top 8 + `ขายเสริม · เครื่องดื่ม`).
    - Built `ReportsPage` and `DailyReportTable` with month `Dropdown` selector, monthly summary `StatsGroup`, pinned left `วันที่` column (`"ยังไม่ปิด"` pill when open), horizontally scrollable metric columns on `1024x768`, monthly `รวม` footer (cost/profit summed over closed days only), and row tap navigating to `/bills?date=YYYY-MM-DD`.
    - Added JS parity unit tests (`dashboard_reports_ops_test.dart`), `bloc_test` suite (`dashboard_reports_cubit_test.dart`), widget flow tests (`dashboard_reports_flow_test.dart`), and golden tests (`dashboard_reports_golden_test.dart` at `1024x768` with top safe area `24`, `1366x1024`, and dark mode `1024x768`).
    - Verified every `.dart` file in `app/lib` is `<= 300` lines (`max = 300`).
- **In Progress / Broken:** None.
- **Next Immediate Step:** Proceed to Step F8 (`/setup` — ตั้งค่าร้าน, แพ็กเกจ/เครื่องดื่ม, วัตถุดิบ/สูตรต้นทุน, โต๊ะ, พนักงาน/สิทธิ์, ช่องทางชำระ/PromptPay, ค่าคงที่รายเดือน) per `docs/llms/flutter-plan.md`.
