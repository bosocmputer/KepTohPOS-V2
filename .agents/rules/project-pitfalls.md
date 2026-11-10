---
description: Project-specific self-learning memory distilled from resolved [BLOCKER] defects, recurring bugs, and user corrections (ความจำระยะยาวเฉพาะโปรเจกต์ สกัดจากจุดตายและข้อตกลง)
---
# Project-Specific Pitfall Memory (`Stage 3 Self-Learning Rules`)

> **Anti-Bloat Governance (Strict 1-Line Distillation):**
> 1. **When to Write:** Append a rule here whenever (a) a `[BLOCKER] [CONFIRMED]` defect is fixed, (b) the user corrects a project assumption or invokes `/learn`, or (c) a recurring gotcha is discovered before `/handoff`.
> 2. **Format:** Maximum **1 line per rule**: `- **[Category]:** <What to always do / never do + 1-phrase reason>`
> 3. **Capacity Cap:** Keep at most **30 rules** total (merge overlapping rules if full). Always mirror edits to both `.claude/rules/project-pitfalls.md` and `.agents/rules/project-pitfalls.md`.
> 4. **Safe Across Upgrades:** `rsync --exclude='project-pitfalls.md'` preserves this file during template updates.

## Active Project Pitfalls & Conventions
<!-- Append project-specific 1-line rules below (max 30 rules) -->
- **[DB / Money & VAT Units]:** Store all monetary amounts in `BIGINT` satang (`100 = 1.00 THB`) and `vat_rate` in basis points (`700 = 7.00%`); never use `FLOAT` and always use integer half-up rounding in SQL RPCs.
- **[DB / Merged Table Alias (M3 BLK-01)]:** Every table-lifecycle RPC (`open_table`, `cancel_table`, `move_table`, `merge_tables`) must check and update secondary tables linked via `alias_id` alongside the primary table.
- **[DB / Full Tax Invoice Guard (M5 BLK-01)]:** In `reissue_bill` / `cancel_and_reissue_bill`, if the original bill has `is_full_invoice = true`, preserve `is_full_invoice = true` and require `customer_tax_profile` so a legal Full Tax Invoice is never downgraded to an ABB receipt.
- **[Security / SECURITY DEFINER & Realtime]:** Every `SECURITY DEFINER` RPC must set `SET search_path = public, pg_temp` and verify `shop_id` ownership; every table in `supabase_realtime` publication must have an active `SELECT` RLS policy.
- **[Flutter / POS Multi-Column Widget Tests]:** Set desktop test viewport (`tester.binding.setSurfaceSize(const Size(1280, 800))`) before pumping multi-column POS screens in `flutter test` to prevent false `RenderFlex overflow` failures on default `800x600`.
- **[Flutter / Shared UI & iPad Responsive Reuse (M5d)]:** Always reuse shared components/formatters (`ResponsiveFormRow`, `Confirm`, `FormModal`, `Empty`, `PendingBadge`, `bahtSmart`, and `FontFeature.tabularFigures()`) registered in `/dev/components`; in `TaxIdBranchInput.didUpdateWidget`, only sync `_hq` when `branchCode.isNotEmpty` so toggling HQ off (`''`) does not reset `_hq`.
