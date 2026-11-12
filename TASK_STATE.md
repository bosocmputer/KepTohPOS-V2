# Active Task Handoff State (Updated: 2026-11-11)
- **Current Phase:** Marketing Site Screenshot Refresh on `feat/marketing-site` (Merged with `main@a224e34`)
- **Production & Backend Status:**
  - **Git Branch:** `feat/marketing-site` (Merged `main` UI updates + refreshed `.webp` screenshots in `site/public/shots/`)
  - **Cloudflare Pages Preview:** `keptoh` project (`branch: review`) · **Vercel POS App:** `https://keptoh-staging.vercel.app`
  - **Supabase Project:** `pbujdexhdzglymgnbsuw` (All migrations `000100` through `20261110000100_fix_FullTaxInvoice_exchange_rounding.sql` pushed)
- **Recent Completed Work (`2026-11-11`):**
  - **Marketing Site Screenshots (`site/public/shots/{hero,tables,shift}{,-800}.webp`):** Merged `main` into `feat/marketing-site`, captured new `1024x768` screenshots from Local Supabase Demo Shop (`DEC0DE0001`, PIN `1234`), converted to `1024w` and `800w` `.webp`, and verified `astro build` in `site/`.
  - **Shift Close Guard (`a224e34`):** Blocked closing a shift whenever `openTables.isNotEmpty` and updated `OwingTablesBanner`.
  - **UI Item 1–3 (`57701cb`, `d2d74bc`, `a224e34`):** De-cluttered occupied `TableCard`, unified single `WalkingOrangeLoader`, and made `BusyOverlay` frameless (`size: 260`).
- **Active Project Constraints (See `.claude/rules/project-pitfalls.md` — `11/30` rules):**
  - Money stored in satang (`int`) · Every `app/lib/**/*.dart` (excl. `*.g.dart`) `<= 300` lines · Never read/edit `.env*`
  - Test commands: `cd app && flutter analyze lib test` and `cd app && flutter test <target_test_file>`
- **Next Immediate Step:**
  - Review updated marketing site preview on Cloudflare Pages (`branch: review`) and merge `feat/marketing-site` when ready.

## 🔄 Auto-Synced Git & Session State (Updated: 2026-11-11 23:54:51)
- **Branch & HEAD:** `feat/marketing-site` (`a85431c`)
- **Last Edit Checkpoint:** `last_agent=antigravity | last_edited_file=/Users/nontawatwongnuk/dev_bos/KepTohPOS-V2/.claude/rules/project-pitfalls.md | diff=+1/-0 บรรทัด | updated_at=2026-11-11T16:52:50Z`
- **Uncommitted Changes:** `M .claude/agents/explorer.md; M .claude/rules/model-routing.md; M .claude/rules/project-pitfalls.md; M .claude/settings.json`
- **Recent Commits (`git log -n 5`):**
  - `a85431c chore(site): update hero, tables, and shift screenshots with latest POS UI`
  - `e1c4fdd Merge branch 'main' into feat/marketing-site`
  - `a224e34 feat(shift,ui): block shift close while tables are open and make WalkingOrangeLoader frameless at size 260`
  - `d2d74bc refactor(web): remove duplicate HTML boot loader so Flutter WalkingOrangeLoader is the single cross-platform loader`
  - `5211397 fix(onboarding): keep WalkingOrangeLoader visible throughout boot and browser refresh`
