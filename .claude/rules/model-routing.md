---
description: "(กฎคัดแยกโมเดลอัตโนมัติ Opus วางแผน ➔ Haiku สำรวจไว ➔ Sonnet เขียนโค้ด/ซ่อมบั๊ก/รันเทสต์)"
---
# Automatic Model Routing & Quota Guard

Follow the routing table in `CLAUDE.md` / `AGENTS.md` Section 1 with synchronized subagent ceilings:
- **`explorer` (`haiku` / `flash`, `maxTurns: 15`):** Read-only search (`>3` files), caller tracing, and impact mapping.
- **`implementer` (`sonnet` / `inherit`, `maxTurns: Auto`):** Multi-file surgical implementation (`2–5` files) + Tier 1 tests.
- **`debugger` (`sonnet` / `inherit`, `maxTurns: 18`):** Root-cause investigation under the `2-Strike` circuit breaker.
- **`reviewer` (`sonnet` / `inherit`, `maxTurns: Auto`):** Blocker-only diff review, Tier 2 checks, and browser/E2E verification.
- **Anti-Quota-Drain:** Do not spawn subagents for 1–2 known file edits or single shell commands. Never run >5 browser clicks inside the main `Opus` window.
