# TASK_STATE.md

- **Branch:** `flutter/f2-shell`
- **Completed (F0 + F1 + F2 Shared Components, AppShell & Router):**
  - **F1 Cleanup:** Added unit tests for stock deduction (`before` on `settle`, `after` on `sendRound` + `adjustSent` restore), `promptPayPayload` + `crc16`, and `tableTimer` (`timeLimit` + overdue `late = true`); removed unused `freezed`/`json_serializable`/`build_runner` from `app/pubspec.yaml`.
  - **F2 Shared Components (`app/lib/core/widgets/`):** Implemented `AppIcon`, `Btn`, `Field`/`AppTextInput`, `Dropdown`, `PosStepper`, `Seg`, `Tabs`, `NumPad`, `PinDots`, `Pill`, `Stat`/`StatsGroup`, `PosDataTable`, `Pagination`, `Empty`/`ResultState`, `Modal`, `Confirm`, `AppToast`/`showAppToast`, `ProductCard`, `PageHeader`/`Toolbar`/`SearchBox`/`Avatar`, plus debug showcase `/dev/components` (Light & Dark side-by-side) and `formatters.dart`.
  - **F2 Layout & Router (`app/lib/core/layout/`, `app/lib/core/router/`):** Implemented responsive `AppShell` (`>= 761`: `88px` Header + `365px` slide-over `NavDrawer` with dark scrim; `<= 760`: Bottom nav 4 items + `"เพิ่มเติม"`), role-filtered navigation (`allowedViewsForRole`), routes (`/tables`, `/bills`, `/stock`, `/shift`, `/dashboard`, `/reports`, `/setup`), widget tests, and golden tests (`1366x1024`, `820x1180`, `390x844`).
- **In Progress / Broken:** None.
- **Important Note for F3 & Subsequent BLoC/Cubit Steps:**
  - `domain` functions (`settle`, `sendRound`, `adjustSent`, `takeStock`, `makeBill`, ฯลฯ) แก้ `PosState` ในก้อนเดิม (in-place mutation) → **Bloc/Cubit ต้อง copy state ก่อนเรียกฟังก์ชัน domain แล้วค่อย `emit` state ก้อนใหม่เสมอ**
- **Next Immediate Step:** Start **F3** (`docs/llms/flutter-plan.md`): implement Login (PIN) + Shift (open/close) + role-based menu permissions flow.
