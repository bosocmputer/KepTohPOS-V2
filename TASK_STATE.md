# Active Task Handoff State (Updated: 2026-11-11)
- **Current Phase:** Post-Go-Live / UI Polish on `main` (`M0–M6 DONE`, Production Live on `main`)
- **Production & Backend Status:**
  - **Git Branch:** `main` (`71f5b50` — Agent Guard Template synced; `TableCard` UI density refinement in progress)
  - **Vercel Production URLs:** `https://keptoh-staging.vercel.app` (Primary) and `https://keptohpos-v2-prototype.vercel.app`
  - **Supabase Project:** `pbujdexhdzglymgnbsuw` (All migrations `000100` through `20261110000100_fix_FullTaxInvoice_exchange_rounding.sql` pushed)
- **Recent Feedback Fixes Completed (`2026-11-11`, on `main`):**
  - **Shift Close Guard (`ShiftBloc` / `ShiftPage` / `OwingTablesBanner` / `closeCashShift`):** Blocked closing a shift whenever `openTables.isNotEmpty` (both unpaid `กินก่อนจ่าย` and paid `จ่ายก่อนกิน` tables waiting for `เก็บโต๊ะ`), disabling `close-shift-btn` and displaying a clear banner with open table names.
  - **UI Item 3 (`BusyOverlay` / `WalkingOrangeLoader`):** Removed the white box container from `BusyOverlay` (`onScrim: true`), enlarged the central default `size` from `210` to `260`, and removed hardcoded `size: 180` overrides across sub-pages.
  - **UI Item 2 (`d2d74bc` — `OnboardingLoadingCard` / `index.html`):** Unified boot loader to the single Flutter `WalkingOrangeLoader` across Web/Android/iOS.
  - **UI Item 1 (`57701cb` — `TableCard` / `TableLiveTimer` / `ZoneTablesSection`):** De-cluttered occupied table card and widened zone grid breakpoints to 4 columns below `1440px`.
- **Active Project Constraints (See `.claude/rules/project-pitfalls.md` — `11/30` rules):**
  - Money stored in satang (`int`) · Every `app/lib/**/*.dart` (excl. `*.g.dart`) `<= 300` lines · Never read/edit `.env*`
  - Test commands: `cd app && flutter analyze lib test` and `cd app && flutter test <target_test_file>`
- **Next Immediate Step:**
  - Verify live Vercel deployment (`https://keptoh-staging.vercel.app`) for frameless `WalkingOrangeLoader(size: 260)` and shift-close open-table guard.

## 🔄 Auto-Synced Git & Session State (Updated: 2026-11-11 14:31:26)
- **Branch & HEAD:** `main` (`d2d74bc`)
- **Last Edit Checkpoint:** `last_agent=antigravity | last_edited_file=/Users/nontawatwongnuk/dev_bos/KepTohPOS-V2/TASK_STATE.md | diff=+7/-7 บรรทัด | updated_at=2026-11-11T07:31:24Z`
- **Uncommitted Changes:** `M app/lib/core/widgets/busy_overlay.dart; M app/lib/core/widgets/lottie_loading.dart; M app/lib/features/bills/presentation/pages/bills_page.dart; M app/lib/features/onboarding/presentation/owner_shop_step.dart; M app/lib/features/reports/presentation/widgets/sales_tax_report_tab.dart; M app/lib/features/setup/presentation/widgets/setup_devices_panel.dart`
- **Recent Commits (`git log -n 5`):**
  - `d2d74bc refactor(web): remove duplicate HTML boot loader so Flutter WalkingOrangeLoader is the single cross-platform loader`
  - `5211397 fix(onboarding): keep WalkingOrangeLoader visible throughout boot and browser refresh`
  - `57701cb feat(tables): declutter occupied TableCard UI and widen zone grid breakpoints`
  - `71f5b50 chore(agent): sync governance rules, verify command, and handoff state`
  - `94ce7cf chore(agent-guard): upgrade to Single Source of Truth + Pitfall Memory & Next Steps reporting`
