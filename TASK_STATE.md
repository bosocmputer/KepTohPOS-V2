# Active Task Handoff State (Updated: 2026-11-12)
- **Current Phase:** Marketing Site Copy & Dark-Theme Logo Refresh on `feat/marketing-site`
- **Production & Backend Status:**
  - **Git Branch:** `feat/marketing-site` (Updated Thai copy for all buffet types + transparent dark-mode `logo_name.png`)
  - **Cloudflare Pages Preview:** `https://review.keptoh.pages.dev` (`https://e31ca971.keptoh.pages.dev`) · **Vercel POS App:** `https://keptoh-staging.vercel.app`
  - **Supabase Project:** `pbujdexhdzglymgnbsuw` (All migrations `000100` through `20261110000100_fix_FullTaxInvoice_exchange_rounding.sql` pushed)
- **Recent Completed Work (`2026-11-12`):**
  - **Marketing Site Contact Details & LINE QR (`site/`):** Updated `LINE_ID` (`@428wicvw`), `PHONE` (`082-929-5566`), `EMAIL` (`contact@orderone.co.th`) in `site/src/config.ts`, added `line_qr.png` to `Footer.astro`, removed placeholder contact notice, and updated Thai copy (`th.json`) + dark-mode `logo_name.png`.
  - **Marketing Site Screenshots (`a85431c`):** Captured new `1024x768` `.webp` screenshots from Local Supabase Demo Shop.
- **Active Project Constraints (See `.claude/rules/project-pitfalls.md` — `12/30` rules):**
  - Money stored in satang (`int`) · Every `app/lib/**/*.dart` (excl. `*.g.dart`) `<= 300` lines · Never read/edit `.env*`
  - Test commands: `cd app && flutter analyze lib test` and `npm --prefix site run build`
- **Next Immediate Step:**
  - Review `https://review.keptoh.pages.dev` and merge `feat/marketing-site` into `main` when ready.

## 🔄 Auto-Synced Git & Session State (Updated: 2026-11-12 11:47:27)
- **Branch & HEAD:** `feat/marketing-site` (`2f95bd6`)
- **Last Edit Checkpoint:** `last_agent=antigravity | last_edited_file=/Users/nontawatwongnuk/dev_bos/KepTohPOS-V2/TASK_STATE.md | diff=+2/-2 บรรทัด | updated_at=2026-11-12T04:47:16Z`
- **Uncommitted Changes:** `M .claude/rules/project-pitfalls.md`
- **Recent Commits (`git log -n 5`):**
  - `2f95bd6 feat(site): broaden copy for all buffet types, update dark logo, and add official contacts + LINE QR`
  - `2b82e34 chore(demo,rules): keep table T02 open in demo seed and sync agent rules`
  - `a85431c chore(site): update hero, tables, and shift screenshots with latest POS UI`
  - `e1c4fdd Merge branch 'main' into feat/marketing-site`
  - `a224e34 feat(shift,ui): block shift close while tables are open and make WalkingOrangeLoader frameless at size 260`
