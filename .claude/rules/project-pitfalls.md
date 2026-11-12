---
description: Project-specific self-learning memory distilled from resolved [BLOCKER] defects, recurring bugs, and user corrections (ความจำระยะยาวเฉพาะโปรเจกต์ สกัดจากจุดตายและข้อตกลง)
---
# Project-Specific Pitfall Memory (`Stage 3 Self-Learning Rules`)

> **Anti-Bloat Governance (Strict 1-Line Distillation):**
> 1. **When to Write:** Append a rule here whenever (a) a `[BLOCKER] [CONFIRMED]` defect is fixed, (b) the user corrects a project assumption or invokes `/learn`, or (c) a recurring gotcha is discovered before `/handoff`.
> 2. **Format:** Maximum **1 line per rule**: `- **[Category]:** <What to always do / never do + 1-phrase reason>`
> 3. **Capacity Cap:** Keep at most **30 rules** total (merge overlapping rules if full). Single Source of Truth: `.agents/rules/project-pitfalls.md` automatically imports this file via `@[project-pitfalls](../../.claude/rules/project-pitfalls.md)`.
> 4. **Safe Across Upgrades:** `rsync --exclude='project-pitfalls.md'` preserves this file during template updates.

## Active Project Pitfalls & Conventions
<!-- Append project-specific 1-line rules below (max 30 rules) -->
- **[DB / Money & VAT Units]:** Store all monetary amounts in `BIGINT` satang (`100 = 1.00 THB`) and `vat_rate` in basis points (`700 = 7.00%`); never use `FLOAT` and always use integer half-up rounding in SQL RPCs.
- **[DB / Merged Table Alias (M3 BLK-01)]:** Every table-lifecycle RPC (`open_table`, `cancel_table`, `move_table`, `merge_tables`) must check and update secondary tables linked via `alias_id` alongside the primary table.
- **[DB / Full Tax Invoice Guard (M5 BLK-01)]:** In `reissue_bill` / `cancel_and_reissue_bill`, if the original bill has `is_full_invoice = true`, preserve `is_full_invoice = true` and require `customer_tax_profile` so a legal Full Tax Invoice is never downgraded to an ABB receipt.
- **[Security / SECURITY DEFINER & Realtime]:** Every `SECURITY DEFINER` RPC must set `SET search_path = public, pg_temp` and verify `shop_id` ownership; every table in `supabase_realtime` publication must have an active `SELECT` RLS policy.
- **[Flutter / POS Multi-Column Widget Tests]:** Set desktop test viewport (`tester.binding.setSurfaceSize(const Size(1280, 800))`) before pumping multi-column POS screens in `flutter test` to prevent false `RenderFlex overflow` failures on default `800x600`.
- **[Flutter / Shared UI & iPad Responsive Reuse (M5d)]:** Always reuse shared components/formatters (`ResponsiveFormRow`, `Confirm`, `FormModal`, `Empty`, `PendingBadge`, `bahtSmart`, and `FontFeature.tabularFigures()`) registered in `/dev/components`; in `TaxIdBranchInput.didUpdateWidget`, only sync `_hq` when `branchCode.isNotEmpty` so toggling HQ off (`''`) does not reset `_hq`.
- **[E2E / Turnstile & Playwright Device Pairing (M6)]:** Cloudflare Turnstile (`CAPTCHA_SITE_KEY`) on Staging blocks automated browsers (`navigator.webdriver`) during `DeviceSession.claim` (`signInAnonymously`); always run automated Playwright/Flutter Drive browser flows against Local Supabase Docker (`keptoh-pos`) with `CAPTCHA_SITE_KEY` unset.
- **[Auth / Device Re-Pairing & Per-Bill Rounding]:** Always clear `auth_user_id = null` on revoked `devices` rows in `leave_device`/`claim_device` and sign out `_deviceAuth` when `pairedShopId()` returns `null`; forward per-bill `roundingOverride` (`p_rounding`) to `settle_bill` so client and server totals match.
- **[Communication / End-of-Task Next Steps]:** Always include a concise `### ⏭️ ขั้นตอนถัดไป (Next Steps)` section at the end of every completed task so the user knows the exact next actions (e.g., DB migration push, staging deploy, or next feature).
- **[Flutter / Single Loading Indicator (`BusyOverlay` & `WalkingOrangeLoader`)]:** Wrap sequential Supabase calls in `NetworkActivity.instance.hold(...)` to prevent overlay flicker, never render a duplicate in-page `WalkingOrangeLoader` while `BusyOverlay` is active, and pass `isOverlay: true` on standalone boot loaders (`OnboardingLoadingCard`) where `BusyOverlay` is disabled.
- **[Shift / Open Tables Guard]:** Always block closing a shift (`ShiftBloc._onClosed`, `ShiftPage`, and `closeCashShift`) whenever `openTables.isNotEmpty`—including `จ่ายก่อนกิน` tables with `due == 0` that have not been cleared (`เก็บโต๊ะ`) yet.
- **[Demo Shop & Marketing Site]:** Before capturing `demo_shop.sql` screenshots, set `ALTER ROLE authenticated SET statement_timeout = '60s'; ANALYZE;` on `supabase_db_keptoh-pos`, pre-inject `flutter.keptoh-device-session` and `flutter.keptoh-staff-session-<shopId>` into `localStorage`, and pass `--yes` to `npx` (`npx --yes wrangler pages deploy`).
- **[Video / AI Studio One-Shot TTS]:** Always synthesize Thai promo voiceovers as a single continuous one-shot script in Google AI Studio (`gemini-3.8-flash-tts`, `Speaker 1 - Fola`, `Temperature = 0.7`, unified storytelling `Style`, `<short pause>`/`<long pause>` only) and align subtitles via waveform pause detection without cutting or splicing the audio.
- **[Printer / Thermal BLE & ESC/POS Raster (`MP80C1`)]:** Render Thai receipts as 1-bit monochrome raster bitmaps (`GS v 0`, 576px for 80mm / 384px for 58mm) to bypass CP437 charset limits and pair BLE thermal printers (`MP80C1`) via in-app Web Bluetooth (`PrinterHub`) rather than iOS/iPadOS Settings.
