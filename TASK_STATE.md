# Active Task Handoff State (Updated: 2026-11-11)
- **Current Phase:** Post-Go-Live / UI Polish on `main` (`M0–M6 DONE`, Production Live on `main`)
- **Production & Backend Status:**
  - **Git Branch:** `main` (`71f5b50` — Agent Guard Template synced; `TableCard` UI density refinement in progress)
  - **Vercel Production URLs:** `https://keptoh-staging.vercel.app` (Primary) and `https://keptohpos-v2-prototype.vercel.app`
  - **Supabase Project:** `pbujdexhdzglymgnbsuw` (All migrations `000100` through `20261110000100_fix_FullTaxInvoice_exchange_rounding.sql` pushed)
- **Recent Feedback Fixes Completed (`2026-11-11`, on `main`):**
  - **UI Item 1 (`TableCard` / `TableLiveTimer` / `ZoneTablesSection`):** De-cluttered occupied table card (merged package + timing subtitle, removed duplicate `รอชำระ` next to countdown timer, kept `เช็กบิล` amount visible during overtime, shortened slip button to `สลิป`, and widened grid breakpoints to 4 columns below `1440px`).
  - `71f5b50`: Synced `.claude/` governance rules, `/verify`, and handoff state onto `main`
  - `44c80f4` / `bc6d8c5`: Quiet offline outbox flush & sales tax report alignment
- **Active Project Constraints (See `.claude/rules/project-pitfalls.md` — `10/30` rules):**
  - Money stored in satang (`int`) · Every `app/lib/**/*.dart` (excl. `*.g.dart`) `<= 300` lines · Never read/edit `.env*`
  - Test commands: `cd app && flutter analyze lib test` and `cd app && flutter test <target_test_file>`
- **Next Immediate Step:**
  - Proceed to the user's next UI adjustment item (`รายการข้อที่ 2`) or commit/deploy the `TableCard` UI refinement.

## 🔄 Auto-Synced Git & Session State (Updated: 2026-11-11 13:23:23)
- **Branch & HEAD:** `main` (`71f5b50`)
- **Last Edit Checkpoint:** `last_agent=antigravity | last_edited_file=/Users/nontawatwongnuk/dev_bos/KepTohPOS-V2/TASK_STATE.md | diff=+13/-19 บรรทัด | updated_at=2026-11-11T06:22:58Z`
- **Uncommitted Changes:** `M app/lib/features/tables/presentation/widgets/table_card.dart; M app/lib/features/tables/presentation/widgets/table_live_timer.dart; M app/lib/features/tables/presentation/widgets/tables_zone_section.dart; ?? site/`
- **Recent Commits (`git log -n 5`):**
  - `71f5b50 chore(agent): sync governance rules, verify command, and handoff state`
  - `94ce7cf chore(agent-guard): upgrade to Single Source of Truth + Pitfall Memory & Next Steps reporting`
  - `44c80f4 fix(sync): flush offline outbox quietly in background without blocking UI`
  - `bc6d8c5 feat(reports): align sales tax report UI with daily reports and prevent duplicate orange loader`
  - `87da026 feat(ui): enlarge Walking_Orange loader, unify boot screen, and remove receipt fresh banner`
