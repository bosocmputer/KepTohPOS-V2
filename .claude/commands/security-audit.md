---
description: Run a high-signal, false-positive-free security audit on changed files or the release scope using Cloudflare's security-audit-skill protocol (ตรวจความปลอดภัยเชิงลึกไร้ False-Positive ตามแนวทาง Cloudflare)
argument-hint: [scope or branch]
allowed-tools: Agent, Read, Grep, Glob, Bash
---
# `/security-audit` — High-Signal Security Audit (`cloudflare/security-audit-skill` Protocol)

Inspect the requested scope (`$ARGUMENTS`, or `git --no-optional-locks diff main...HEAD` if omitted) using the rules in `.claude/skills/security-audit/SKILL.md`:

## Step 1: Surface & Trust-Boundary Mapping (`explorer` / `haiku`)
Spawn `Agent(subagent_type="explorer", model="haiku")` to locate all security-critical surfaces in scope:
1. Database migrations, `SECURITY DEFINER` RPCs, and RLS policies (`supabase/migrations/*.sql` or schema files).
2. Authentication, session/token handling, device pairing/revocation, and role/permission checks.
3. Offline outbox replay (`OutboxQueue` / `SyncEngine`) and Realtime channel subscriptions.
4. External inputs, webhooks, or LLM/tool boundaries.

## Step 2: Adversarial Invariant Verification (`reviewer` / `sonnet`)
Spawn `Agent(subagent_type="reviewer", model="sonnet")` to verify whether any concrete invariant can be violated:
- Require all 6 elements for any finding: **Lower-Trust Principal**, **Accepted Input/Action**, **Intended Control**, **Crossed Trust Boundary**, **Affected Principal/Resource**, and **Ordered Trace (`entrypoint` ➔ `propagation` ➔ `sink` with `file:line`)**.
- Strictly separate findings into 3 buckets:
  1. **🔴 `[CONFIRMED]`** — Proven in repository source code (`overall_severity <= impact`).
  2. **🟡 `[NEEDS_VALIDATION]`** — Depends on external dashboard/cloud configuration not visible in Git (no severity assigned; provide 1-line check).
  3. **⚪ `[HARDENING]`** — Non-blocking defense-in-depth notes where an existing control already prevents exploitation.
