# TASK_STATE.md

- **Branch:** `flutter/f4b-payment`
- **Completed (F0 + F1 + F2 + F3 + F4a + F4b Payment & Receipt):**
  - **Installed Skill (`tech-stack-skills` -> `flutter-expert`):**
    - Installed `.agents/skills/flutter-expert/` (`SKILL.md` + `references/`) via `bash .claude/hooks/install-skill.sh flutter-expert` and applied `bloc-state.md` and `widget-patterns.md`.
  - **Theme & Brand Logo (`feat(theme): switch to team palette and new logo` — commit `8a627a7`):**
    - Replaced all token values in `app/lib/core/theme/raw_tokens.dart` and `app/lib/core/theme/tokens.dart` with the team palette (`primary: #FF7A00`, `onPrimary: #20242C`, `bg: #F4F4F5`, `side: #172033`, `success: #16A36A`, `danger: #E5484D`) in Light and Dark modes (zero `figma` color constants remaining).
    - Bundled `app/assets/logo.jpg` and `app/assets/logo_name.jpg`, updated `app/web/favicon.png` & `app/web/icons/*`, and added `BrandLogo` and `BrandLogoName` widgets (`BoxFit.contain` on white rounded containers) used across `LoginPage`, `LoginHeroPanel`, `AppNavDrawer`, and `ReceiptCard`.
  - **Sale & Figma Alignment (`fix(sale): align topbar, icons, order panel and catalog with Figma` — commit `3eb6d15`):**
    - Replaced Material `Icons.*` in `app/lib/core/widgets/app_icon.dart` with `HugeIcons.strokeRounded*` (`hugeicons: ^0.0.7`) and added `AppIcons.forCategory` & `AppIcons.forPaymentType` helpers (zero `Icons.*` outside `app_icon.dart`).
    - Aligned `ShellHeaderBar` (left Sidebar toggle + SearchBox; right contextual `เปิดโต๊ะ` / `เก็บโต๊ะ` + shift status pill + Avatar) and `AppShell` (`ShellDesktopHeaderScope` so `SalePage`'s right `396px` Order Panel spans 100% height on `>= 761`).
    - Updated `TableCard` (`'table'` dining icon), `ProductCard` (category icon), `SalePackagesList` (leading `36x36` package icon badge), `SaleAddonsGrid` (4 columns at `1366`, 3 columns at `1024`), and `OrderLine` (leading `36x36` category icon badge + inline note button).
  - **Payment & Receipt Settlement (`feat(payment): cash, PromptPay and transfer settlement with receipt`):**
    - Implemented `SalePaymentPanel`, `CashPaymentSection` (quick cash `พอดี` / `฿100` / `฿500` / `฿1,000`, `NumPad`, change/shortfall display), `PromptPayQR` (`qr_flutter` + `promptPayPayload`), `TransferStatusSection` (`waiting` / `success` / `failed`), `ReceiptCard`, and `ReceiptModal` (with `BrandLogo` `logo.jpg`).
    - Extended `SaleBloc`, `SaleState`, and `SaleEvent` with `step` (`'order'` / `'pay'`), `methodId`, `cashReceived`, `transferState`, `settledBill`, and `SalePaymentSubmitted` calling `settle(...)` from `domain/settle.dart`.
    - Added unit (`order_settle_test.dart`), bloc (`sale_bloc_test.dart`), widget (`tables_sale_flow_test.dart`), and golden (`tables_sale_golden_test.dart`) tests covering cash, PromptPay QR, bank transfer, and receipt modal.
- **In Progress / Broken:** None.
- **Next Immediate Step:** Proceed to `/bills` history + void bill (`voidBill`) and `/shift` / `/stock` / `/expenses` / `/reports` / `/setup` per `docs/llms/flutter-plan.md`.
