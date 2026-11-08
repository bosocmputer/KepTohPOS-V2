---
name: security-audit
description: Use when auditing authentication, RLS/multi-tenant data isolation, SECURITY DEFINER RPCs, offline/realtime sync, or release readiness using Cloudflare's false-positive-free security audit protocol (ใช้เมื่อต้องการตรวจสอบความปลอดภัยเชิงลึกแบบไร้ False-Positive ตามแนวทาง Cloudflare)
---
# Security Audit & Invariant Verification (`cloudflare/security-audit-skill` Protocol)

> **Reference Architecture:** [`cloudflare/security-audit-skill`](https://github.com/cloudflare/security-audit-skill) (`SKILL.md`, `ATTACK-CLASSES.md`, `DATA-ISOLATION-AND-LIFECYCLE.md`, `WEB-PROTOCOL-AND-AUTH.md`, `AI-AND-LLM.md`, `VALIDATION-AND-REPORTING.md`)

## 1. The Iron Law
> **EVERY FINDING REQUIRES A 6-ELEMENT CONCRETE INVARIANT AND AN ENTRYPOINT-TO-SINK SOURCE TRACE. NEVER CONFUSE DEFENSE-IN-DEPTH OR UNOBSERVED CLOUD CONFIG WITH A CONFIRMED VULNERABILITY.**

## 2. Operating Modes (Zero Ceremony Overhead)
1. **Guidance / Focused Diff Mode (Default):** When reviewing a PR, migration, or feature (`M1–M5`), inspect only the changed entry surfaces, RPCs, RLS policies, and state transitions in-place. Do **not** generate external JSON ledgers.
2. **Pre-Release Audit Mode (`/security-audit`):** When explicitly triggered (e.g., before Production release / `M6`), delegate surface mapping to `explorer` (`haiku`) and adversarial verification to `reviewer` (`sonnet`).

## 3. The 6-Element Concrete Invariant Gate
Before reporting any `[CONFIRMED]` vulnerability, you **must** verify all 6 elements from repository source code:
1. **Lower-Trust Principal:** Who is acting (unauthenticated caller, staff with revoked PIN/token, user from another `shop_id`/tenant, untrusted webhook/LLM input)?
2. **Accepted Input / Action:** What parameter, payload, RPC call, or state transition is sent?
3. **Intended Control:** Which check (`RLS`, `SECURITY DEFINER` guard, role check, state transition `WHERE` clause) was supposed to stop or scope it?
4. **Crossed Trust Boundary:** Exact `file:line` where the check is missing, bypassed, or mismatched.
5. **Affected Principal / Resource:** Whose data, money, or service availability is impacted (must be distinct from self-harm)?
6. **Ordered Source Trace:** `entrypoint` (`file:line`) ➔ `propagation` (`file:line`) ➔ `sink` (`file:line`).

## 4. High-Yield Attack Classes (`Cloudflare Companions`)

### A. Multi-Tenant Data Isolation & Lifecycle (`DATA-ISOLATION-AND-LIFECYCLE`)
- **Cross-Tenant / Cross-Shop Scope Bypass:**
  - Do `SECURITY DEFINER` SQL functions or backend handlers accept `p_shop_id` / `tenant_id` from the client payload without verifying `auth.uid()` or active device/staff membership in that shop?
  - Are Realtime channels, cached snapshots, or export queries scoped strictly by tenant/shop?
- **Lifecycle, Revocation & Offline-Replay Drift:**
  - When a device pairing link is `revoked`/`expired` or a staff member is deactivated (`is_active = false`), can stale offline tokens or queued `OutboxQueue` commands still execute privileged RPCs?
  - Can a settled (`paid`) or `voided` bill/order be mutated, re-settled, or double-refunded by replaying an out-of-order request?

### B. Web Protocol, Auth & Session Binding (`WEB-PROTOCOL-AND-AUTH`)
- **State-Transition & Idempotency Races (TOCTOU):**
  - If two devices simultaneously open the same table, apply a discount, or settle the same bill, does the database enforce atomic conditional updates (`UPDATE ... WHERE status = 'open'`) and idempotency keys?
- **Privilege & Cost Visibility:**
  - If a role restriction exists (e.g., `can_view_costs = false`), is cost data stripped at the data/snapshot boundary rather than merely hidden in UI widgets?

### C. AI, Tool-Calling & MCP Boundaries (`AI-AND-LLM`)
- **Confused-Deputy vs. Action-Binding:**
  - Prompt injection alone is not a finding unless untrusted content crosses a deterministic code boundary to invoke a state-changing tool or leak cross-principal data without user approval.

## 5. Three-Tier Verdict Separation (Anti-Hallucination)
1. **🔴 `[CONFIRMED]` (With Severity: `Critical | High | Medium | Low`):**
   - Fully proven in repository code with an `entrypoint` ➔ `sink` trace.
   - **Rule (`overall_severity <= impact`):** Overall severity can never exceed the demonstrated real-world impact.
2. **🟡 `[NEEDS_VALIDATION]` (No Severity Assigned):**
   - Source trace is reachable in code, but exploitability depends on an external setting not visible in Git (e.g., Supabase Auth Dashboard settings, Cloudflare Turnstile secret enforcement, Vercel Production env vars). State the exact 1-line check required.
3. **⚪ `[HARDENING]` (Non-Blocking Defense-in-Depth):**
   - An existing control already blocks the attack, so no vulnerability exists, but a secondary safeguard is worth noting.

## 6. Required Output Format
```markdown
### 🛡️ Security Audit Summary (`cloudflare/security-audit-skill` Gate)
- **Scope Inspected:** [List RPCs / migrations / repositories / flows inspected]
- **🔴 Confirmed Vulnerabilities (`[CONFIRMED]`):** [None / List with `entrypoint -> sink` (`file:line`), Principal, Impact, and Surgical Fix]
- **🟡 External Config Checks (`[NEEDS_VALIDATION]`):** [None / 1-line dashboard or env verification steps]
- **⚪ Defense-in-Depth Notes (`[HARDENING]`):** [None / Brief optional hardening notes]
```
