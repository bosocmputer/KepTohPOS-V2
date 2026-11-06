# TASK_STATE.md

- **Branch:** `flutter/ui-polish` (HEAD `673b09d`, branched from `main` `f605091` after merging F7 `flutter/f7-dashboard-reports` `657800a`)
- **Completed (F0–F7 merged to `main` + F8 `/setup` & UI Polish & 3-Day Simulation on `flutter/ui-polish`):**
  - **Step F7 Dashboard & Reports (`main` `f605091` / `657800a`):** Completed `computeDashboardSummary`, `computeMonthlyReport`, `DashboardCubit`, `ReportsCubit`, `DashboardPage`, `ProfitChart` (`CustomPainter`), `ReportsPage`, `DailyReportTable`, and 130 passing tests.
  - **Step F8 Setup + UI Polish + 3-Day Simulation (`flutter/ui-polish` `673b09d`):**
    - Implemented `/setup` (13 sections across 4 groups) with pure domain CRUD & JSON import/export in `app/lib/domain/setup_ops.dart`, `SetupCubit`, `SetupPage`, CRUD modals, `CrudSectionShell`, and `AppSwitch`.
    - Added pure domain demo/simulation helpers in `app/lib/domain/demo_sim_ops.dart` (`clearDailyTransactionsInState`, `advanceSimulationDayInState` with open-table/open-shift safety guards) + `Confirm` modals in `SetupPage`.
    - Aligned `Dropdown` & `Field` height to `44px` (`RawTokens.formControlHeight`), added pay-before-eating (`before`) occupied table notice + quick `เก็บโต๊ะ` button (`banner-close-table-btn`) in `sale_main_content.dart`, and polished UI across all views.
    - Added `setup_cubit_serialization_test.dart`, `setup_flow_test.dart`, `three_day_simulation_test.dart` (3-day accounting audit), and `three_day_ui_flow_test.dart` (3-day Widget UI E2E flow), and updated all goldens (`145/145` tests passing, `flutter analyze` = 0 issues, all files in `app/lib` `<= 300` lines).
- **In Progress / Broken:** None.
- **Next Immediate Step:** Claude review of F7 (`657800a` merged in `main`) and F8 + UI polish (`flutter/ui-polish`), then proceed to Step F9 (final cross-screen & 3-viewport inspection + web build).
