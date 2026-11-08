---
name: pragmatic-review
description: Use when reviewing code changes or diffs for logic bugs and security vulnerabilities using a Blocker-Only policy capped at 2 rounds (ใช้เมื่อต้องการตรวจรีวิวโค้ดเฉพาะจุดที่เป็น Blocker ไม่เกิน 2 รอบ พร้อมตัวกรอง False-Positive ของ Cloudflare)
---
# Pragmatic Code Review & Convergence Gate (`obra/superpowers` + `garrytan/gstack` + `cloudflare/security-audit-skill`)

> **Reference Architecture:** [`obra/superpowers`](https://github.com/obra/superpowers) (`requesting-code-review` & `receiving-code-review`), [`garrytan/gstack`](https://github.com/garrytan/gstack) (`review/checklist.md` & `review/gate-integrity.md`), and [`cloudflare/security-audit-skill`](https://github.com/cloudflare/security-audit-skill) (`VALIDATION-AND-REPORTING.md` & `DATA-ISOLATION-AND-LIFECYCLE.md`)

## 1. The Iron Law
> **TECHNICAL CORRECTNESS OVER SOCIAL COMFORT — REPORT PROVEN BLOCKERS ONLY, ELIMINATE SECURITY THEATER, CONVERGE IN AT MOST 2 ROUNDS.**

## 2. Core Workflow

### Step 1: Diff & Cross-Consumer Inspection
1. Inspect exact changes using `git --no-optional-locks status --short` and `git --no-optional-locks diff` (or `git --no-optional-locks diff BASE_SHA..HEAD_SHA`).
2. **Enum & Value Completeness (`gstack` Pass 1 Rule):** If the diff adds or modifies an enum value, status string, role, or validator shape, `Grep` for sibling values across the codebase **outside the diff** and read every consumer (`switch`/`case`, filter array, DB model) to ensure no unhandled fallthroughs exist.

### Step 2: Severity Triage & Cloudflare False-Positive Gate (`Blocker-Only Policy`)
Categorize findings strictly. Every reported `[BLOCKER]` must be proven from repository source code:

#### 🔴 Report Immediately (`[BLOCKER]` — Source-Confirmed Defects Only):
1. **Broken Logic & Edge Cases:** Incorrect calculations, unhandled `null`/`undefined`/`NaN`, off-by-one errors, unhandled enum values in consumers outside the diff, or broken idempotency (double-submit bug).
2. **Security & Trust Boundaries (`cloudflare/security-audit-skill` Concrete Invariant Gate):**
   - Must trace the concrete path **`entrypoint` (`file:line`) ➔ `propagation` ➔ `sink` (`file:line`)** and identify the lower-trust principal + bypassed control.
   - **Data Isolation & Multi-Tenant Scope (`DATA-ISOLATION-AND-LIFECYCLE`):** `SECURITY DEFINER` RPCs, SQL queries, or Realtime listeners that trust client-supplied `shop_id`/`tenant_id` instead of binding scope from the authenticated session/JWT, or unscoped queries leaking cross-tenant rows.
   - **Lifecycle & Revocation Replay:** Revoked/expired device links, deactivated staff accounts/tokens, or already-settled/voided bills that can still apply mutations via offline outbox replay or Realtime events.
   - **LLM / Tool Action-Binding:** Unvalidated external/LLM inputs written to sinks or triggering state-changing tools without caller authorization.
3. **Data Corruption & TOCTOU Race Conditions:**
   - Missing database transactions on multi-table writes.
   - Read-then-write (TOCTOU) status transitions (e.g., two devices opening/settling the same table or bill simultaneously) that lack atomic `UPDATE ... WHERE status = expected_old_status` or unique constraints.
4. **Gate Integrity & Anti-Reward-Hacking (`gstack RH-1..RH-16`):**
   - `RH-1`: Deleted, `.skip`-ed, or `.only`-ed tests.
   - `RH-3 / RH-5`: Unowned `.snap` regeneration or tautological tests that only assert their own mock setup.
   - `RH-12`: Environment sniffing in production code (`if (process.env.NODE_ENV === 'test')` or `if (process.env.CI)`).
   - `RH-13 / RH-15 / RH-16`: Added `@ts-ignore`/`eslint-disable`, relaxed numeric thresholds/timeouts to hide failures, or empty `catch {}` blocks.
5. **Severe Performance Defects:** N+1 queries inside loops, unbounded `SELECT *`, or memory/subscription leaks (e.g., unclosed Realtime channels or streams).

#### 🟡 Separate Unobserved External Dependencies (`[NEEDS_VALIDATION]` — Never Inflate to Blocker):
- **Cloudflare No-Speculation Rule:** If safety depends on an external setting not visible in the repository (e.g., Supabase Dashboard Auth settings, Cloudflare Turnstile/WAF rules, Vercel environment variables), **never assume it is broken and never report it as a code `[BLOCKER]`**. List it briefly under `[NEEDS_VALIDATION]` with a 1-line verification step for the user.

#### ⚪ Suppress Completely (Ignore Nitpicks & Defense-in-Depth Theater):
- **Defense-in-Depth ≠ Vulnerability (`Cloudflare Gate`):** If Layer A in the code already prevents the bug/attack (e.g., RLS or parameterized query already blocks injection/unauthorized access), do **not** report the absence of redundant Layer B as a `[BLOCKER]`.
- Formatting, indentation, or subjective naming preferences that do not affect correctness.

### Step 3: Receiving & Applying Review (`receiving-code-review` Protocol)
- **No Hollow Praise:** Skip conversational filler (*"You're absolutely right!"* or *"Great catch!"*).
- **Verify Before Changing:** Trace each reported `[BLOCKER]` against the actual code contract, apply the surgical fix, and run the test suite.

### Step 4: Convergence Circuit Breaker (`MAX_ROUNDS = 2`)
- **Round 1 of 2:** Report all source-confirmed `[BLOCKER]` defects found in the current diff (plus any separate `[NEEDS_VALIDATION]` notes).
- **Round 2 of 2 (`No Moving Goalposts`):** Verify **only** whether Round 1 `[BLOCKER]` items were resolved and whether tests pass. Never invent new critiques on untouched code in Round 2.

## 3. Constraints (`MUST DO` / `MUST NOT DO`)
- **MUST** run the relevant test file to verify behavior before issuing `VERDICT: APPROVE`.
- **MUST** include exact `file:line` references (`entrypoint` ➔ `sink` for security issues) and a concrete fix for every `[BLOCKER]`.
- **MUST NOT** nitpick code style, formatting, or report defense-in-depth wishes as blockers.
- **MUST NOT** exceed 2 review rounds; if unresolved after Round 2, output `VERDICT: ESCALATE_TO_USER`.

## 4. Required Verdict Output Format
```markdown
VERDICT: APPROVE
- ตรวจสอบ `git diff` และรันเทสต์ยืนยันเรียบร้อยแล้ว ไม่พบปัญหาในระดับ Blocker
```
*(Or when blockers exist:)*
```markdown
VERDICT: CHANGES_REQUESTED
- **[BLK-01] [Security / Logic / Race Condition] (`path/to/entry.ts:L18` ➔ `path/to/sink.ts:L64`)**
  - **ปัญหา:** [ระบุสาเหตุที่ทำให้พังหรือเกิดช่องโหว่ พร้อม Principal/Boundary ที่ทะลุ]
  - **วิธีแก้:** [ระบุโค้ดหรือเงื่อนไขที่ต้องแก้ให้ชัดเจน]
- **[NEEDS_VALIDATION] (ถ้ามีคอนฟิกนอกโค้ดที่ต้องให้ผู้ใช้เช็กบน Dashboard):** [ระบุสิ่งที่ต้องเช็ก 1 บรรทัด]
```
