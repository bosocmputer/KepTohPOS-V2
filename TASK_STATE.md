# TASK_STATE.md

- **Branch:** `flutter/f3-auth-shift`
- **Completed (F0 + F1 + F2 + F3 Auth & Shift):**
  - **F2 Fixes (`fix(shell): bundle fonts, align shell and components with Figma`):** Bundled `Anuphan` (`500`/`600`/`700`) and `IBM Plex Sans Thai` (`400`/`500`/`600`/`700`) `.ttf` files in `app/assets/fonts/`, removed `google_fonts`, added `app/test/flutter_test_config.dart` (loading both font families + `MaterialIcons`), aligned `ShellHeaderBar` and `NavPanel` with Figma (`cashier.png` & `cashier_sidebar.png`), moved theme selector to `/setup` and Sidebar shortcut, stretched `PosDataTable` to full container width, updated `Pill` and dark-mode `ProductCard`, clamped today's `shiftOpen` in `seed()`, and updated golden tests (`app_shell_1366x1024_closed.png`, `dev_components_light.png`, `dev_components_dark.png`).
  - **F3 Auth, Shift & Role Access (`feat(auth): PIN login, shift open/close and role-based access`):**
    - Added deep-copy `.copy()` methods on `PosState`, `OpenTableState`, `TableRound`, `BillRecord`, and `ShiftRecord`.
    - Implemented `PosRepository` (`openShiftOf`, `calcShiftStats`, `openShift`, `closeShift`) and `MockPosRepository` (loads `assets/mock/*.json` + `seed()`, deep-copies `PosState` on every `update`) registered via `get_it` (`app/lib/core/di/injection.dart`).
    - Implemented `AuthCubit` + `LoginPage` + `LoginHeroPanel` (staff `Dropdown`, `PinDots` + `NumPad`, wrong-PIN error, left hero panel showing latest closed day profit/loss from `computeLedger`).
    - Implemented `ShiftBloc` + `ShiftPage` + `OpenShiftForm`/`OpenShiftModal` + `ShiftHistoryTable` (starting float, post-login open-shift prompt, cash count vs expected cash & variance diff, owing eat-before-paying tables warning, 14-shift history table).
    - Configured `GoRouter` auth & role-based route guards (`cashier` sees 4 menus and redirects from `/dashboard`, `/reports`, `/setup` to `/tables`).
    - Added `bloc_test` (`app/test/bloc/auth_shift_bloc_test.dart`), widget flow test (`app/test/widget/auth_shift_flow_test.dart`), and Login golden test (`app/test/golden/login_golden_test.dart` -> `login_1366x1024.png`).
- **In Progress / Broken:** None.
- **Important Note for F4 & Subsequent BLoC/Cubit Steps:**
  - `domain` functions (`settle`, `sendRound`, `adjustSent`, `takeStock`, `makeBill`, `openShift`, `closeShift`, ฯลฯ) mutate `PosState` in place -> always use `PosRepository.update((s) { ... })` (which calls `s.copy()` before mutating) and emit the new state instance.
- **Next Immediate Step:** Start **F4** (`docs/llms/flutter-plan.md`): Tables grid, open/edit table, order pad, rounds, merge/move/split, and settlement modal (`before` & `after` billing modes).
