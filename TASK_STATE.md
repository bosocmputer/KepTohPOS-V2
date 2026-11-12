# Active Task Handoff State (Updated: 2026-11-12)
- **Current Phase:** Marketing Site Copy & Dark-Theme Logo Refresh on `feat/marketing-site`
- **Production & Backend Status:**
  - **Git Branch:** `feat/marketing-site` (Updated Thai copy for all buffet types + transparent dark-mode `logo_name.png`)
  - **Cloudflare Pages Preview:** `keptoh` project (`branch: review`) · **Vercel POS App:** `https://keptoh-staging.vercel.app`
  - **Supabase Project:** `pbujdexhdzglymgnbsuw` (All migrations `000100` through `20261110000100_fix_FullTaxInvoice_exchange_rounding.sql` pushed)
- **Recent Completed Work (`2026-11-12`):**
  - **Marketing Site Contact Details & LINE QR (`site/`):** Updated `LINE_ID` (`@428wicvw`), `PHONE` (`082-929-5566`), `EMAIL` (`contact@orderone.co.th`) in `site/src/config.ts`, added `line_qr.png` to `Footer.astro`, removed placeholder contact notice, and updated Thai copy (`th.json`) + dark-mode `logo_name.png`.
  - **Marketing Site Screenshots (`a85431c`):** Captured new `1024x768` `.webp` screenshots from Local Supabase Demo Shop.
- **Active Project Constraints (See `.claude/rules/project-pitfalls.md` — `12/30` rules):**
  - Money stored in satang (`int`) · Every `app/lib/**/*.dart` (excl. `*.g.dart`) `<= 300` lines · Never read/edit `.env*`
  - Test commands: `cd app && flutter analyze lib test` and `npm --prefix site run build`
- **Next Immediate Step:**
  - Deploy updated `site/dist` to Cloudflare Pages (`npx wrangler pages deploy site/dist --project-name keptoh --branch review --yes`) or merge `feat/marketing-site` when ready.

## 🔄 Auto-Synced Git & Session State (Updated: 2026-11-12 11:31:41)
- **Branch & HEAD:** `feat/marketing-site` (`2b82e34`)
- **Last Edit Checkpoint:** `last_agent=antigravity | last_edited_file=/Users/nontawatwongnuk/dev_bos/KepTohPOS-V2/TASK_STATE.md | diff=+14/-15 บรรทัด | updated_at=2026-11-12T04:31:29Z`
- **Uncommitted Changes:** `D site/src/assets/logo_name.jpg; M site/src/components/Footer.astro; M site/src/components/Header.astro; M site/src/config.ts; M site/src/i18n/th.json; M site/src/styles/global.css`
- **Recent Commits (`git log -n 5`):**
  - `2b82e34 chore(demo,rules): keep table T02 open in demo seed and sync agent rules`
  - `a85431c chore(site): update hero, tables, and shift screenshots with latest POS UI`
  - `e1c4fdd Merge branch 'main' into feat/marketing-site`
  - `a224e34 feat(shift,ui): block shift close while tables are open and make WalkingOrangeLoader frameless at size 260`
  - `d2d74bc refactor(web): remove duplicate HTML boot loader so Flutter WalkingOrangeLoader is the single cross-platform loader`
