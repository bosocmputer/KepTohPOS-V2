# Active Task Handoff State (Updated: 2026-11-11)
- **Current Phase:** Post-Go-Live / UI Polish on `main` (`M0–M6 DONE`, Production Live on `main`)
- **Production & Backend Status:**
  - **Git Branch:** `main` (`71f5b50` — Agent Guard Template synced; `TableCard` UI density refinement in progress)
  - **Vercel Production URLs:** `https://keptoh-staging.vercel.app` (Primary) and `https://keptohpos-v2-prototype.vercel.app`
  - **Supabase Project:** `pbujdexhdzglymgnbsuw` (All migrations `000100` through `20261110000100_fix_FullTaxInvoice_exchange_rounding.sql` pushed)
- **Recent Feedback Fixes Completed (`2026-11-11`, on `main`):**
  - **UI Item 2 (`OnboardingLoadingCard` / `index.html`):** Unified boot loader to the single Flutter `WalkingOrangeLoader` across Web/Android/iOS by passing `isOverlay: true` in `OnboardingLoadingCard` and removing the duplicate HTML `#keptoh-boot-loader` (`lottie-web`) from `app/web/index.html`.
  - **UI Item 1 (`57701cb` — `TableCard` / `TableLiveTimer` / `ZoneTablesSection`):** De-cluttered occupied table card and widened zone grid breakpoints to 4 columns below `1440px`.
  - `71f5b50`: Synced `.claude/` governance rules, `/verify`, and handoff state onto `main`
- **Active Project Constraints (See `.claude/rules/project-pitfalls.md` — `10/30` rules):**
  - Money stored in satang (`int`) · Every `app/lib/**/*.dart` (excl. `*.g.dart`) `<= 300` lines · Never read/edit `.env*`
  - Test commands: `cd app && flutter analyze lib test` and `cd app && flutter test <target_test_file>`
- **Next Immediate Step:**
  - Commit and push the `OnboardingLoadingCard` + `index.html` boot loader fix to `main` (Vercel auto-deploy) when approved by user.

## 🔄 Auto-Synced Git & Session State (Updated: 2026-11-11 13:50:37)
- **Branch & HEAD:** `main` (`5211397`)
- **Last Edit Checkpoint:** `last_agent=antigravity | last_edited_file=/Users/nontawatwongnuk/dev_bos/KepTohPOS-V2/TASK_STATE.md | diff=+7/-7 บรรทัด | updated_at=2026-11-11T06:41:29Z`
- **Uncommitted Changes:** `?? site/`
- **Recent Commits (`git log -n 5`):**
  - `5211397 fix(onboarding): keep WalkingOrangeLoader visible throughout boot and browser refresh`
  - `57701cb feat(tables): declutter occupied TableCard UI and widen zone grid breakpoints`
  - `71f5b50 chore(agent): sync governance rules, verify command, and handoff state`
  - `94ce7cf chore(agent-guard): upgrade to Single Source of Truth + Pitfall Memory & Next Steps reporting`
  - `44c80f4 fix(sync): flush offline outbox quietly in background without blocking UI`
