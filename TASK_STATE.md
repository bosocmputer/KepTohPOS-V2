# TASK_STATE.md

- **Branch:** `flutter/f4c-ui-polish`
- **Completed (F0 + F1 + F2 + F3 + F4a + F4b + F4c UI Polish):**
  - **Installed Skill (`tech-stack-skills` -> `flutter-expert`):**
    - Installed `.agents/skills/flutter-expert/` (`SKILL.md` + `references/`) and applied `widget-patterns.md` + `root-cause-debug` + `pragmatic-review` + `verification-before-completion`.
  - **5 UI Bugs Fixed (`root-cause-debug`):**
    - **Bug 1 (Dropdown):** Rewrote `Dropdown<T>` in `app/lib/core/widgets/dropdown.dart` using `LayerLink` + `OverlayPortal` + `CompositedTransformTarget` + `CompositedTransformFollower` with automatic upward flip when space below is insufficient; added widget test verifying `StatsGroup` position is unchanged when `/tables` zone dropdown opens.
    - **Bug 2 (SafeArea):** Extended background of `ShellHeaderBar`, `AppNavDrawer`, `SaleOrderPanel`, `SalePaymentPanel`, and `LoginHeroPanel` under top status bar and bottom home indicator while keeping interactive content inside `SafeArea`.
    - **Bug 3 (Topbar Alignment):** Used shared `AppDimensions.pagePadding(screenWidth)` (`16` at `1024`, `24` at `>= 1180`) in `ShellHeaderBar` and content areas, replaced `Flexible` around `SearchBox` with fixed `SizedBox(width: AppDimensions.topbarSearchW)` so `Spacer()` pushes right actions/Avatar flush right, and fixed `PageHeader` right-action alignment.
    - **Bug 4 (Cash Payment Panel):** Made `CashPaymentSection` fit completely at `1024x768` + top `24` safe area by using scrollable middle content, pinned bottom `ยืนยันรับเงินสด` / `กลับไปแก้รายการ` footer (`52px` primary button), and `NumPad` `keyHeight = 48` when screen height `< 900`.
    - **Bug 5 (Receipt Modal):** Capped `Modal` max height at `90%` (`modalMaxHeightFactor = 0.90`) inside `SafeArea`, made receipt content scrollable inside `Flexible(child: SingleChildScrollView(...))`, pinned `พิมพ์ใบเสร็จ` / `เสร็จสิ้น` footer buttons at bottom, and suppressed background toast when a modal is open.
  - **Proportional Tokens & Deduplication (`raw_tokens.dart` & `app_theme.dart`):**
    - Enforced spacing scale `4 / 8 / 12 / 16 / 24 / 32`, `H1 = 24` (`โต๊ะ A2` & `PageHeader`), `H2 = 18`, body `15–16`, money `28–32`, button height `44` / `52`, card & button radius `12`, Topbar `72` (`1024`) / `88` (`>= 1180`), right panel `360` (`1024`) / `396` (`>= 1180`), and product grid `3` cols (`1024`) / `4` cols (`>= 1180`).
    - Removed duplicate `"เก็บโต๊ะ"` button in `SaleMainContent` and duplicate `SearchBox` in `TablesPage` `PageHeader`; verified Sidebar white background (`#FFFFFF` in Light mode) and orange (`#FF7A00`) + charcoal (`#20242C`) active menu item in Light and Dark modes.
  - **Golden Coverage (`1024x768`, `1180x820`, `1366x1024`):**
    - Added and verified golden tests for `login`, `tables`, `tables+dropdown`, `sale`, `payment_cash`, `payment_promptpay`, and `receipt` at all 3 tablet sizes including simulated `SafeArea` padding.
- **In Progress / Broken:** None.
- **Next Immediate Step:** Proceed to `/bills` history + void bill (`voidBill`) and `/shift` / `/stock` / `/expenses` / `/reports` / `/setup` per `docs/llms/flutter-plan.md`.
