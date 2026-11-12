---
description: "(กฎคัดแยกโมเดลอัตโนมัติ Opus วางแผน ➔ Haiku สำรวจไว ➔ Sonnet เขียนโค้ด/ซ่อมบั๊ก/รันเทสต์)"
---
# Automatic Model Routing & Quota Guard

Follow the routing table in `CLAUDE.md` / `AGENTS.md` Section 1 with synchronized subagent ceilings:
- **`explorer` (`haiku` / `flash`, `maxTurns: 15`):** Read-only search (`>3` files), caller tracing, impact mapping, and web research (`WebSearch`/`WebFetch`).
- **`implementer` (`sonnet` / `inherit`, `maxTurns: 35`):** Multi-file surgical implementation (`2–5` files) + Tier 1 tests.
- **`debugger` (`sonnet` / `inherit`, `maxTurns: 18`):** Root-cause investigation under the `2-Strike` circuit breaker.
- **`reviewer` (`sonnet` / `inherit`, `maxTurns: 35`):** Blocker-only diff review, Tier 2 checks, and browser/E2E verification.
- **Anti-Quota-Drain:** Do not spawn subagents for 1–2 known file edits or single shell commands. Never run >5 browser clicks inside the main `Opus` window.
- **Fresh Subagent per Distinct Task (No Stale Context Reuse):** Never `send_message` to reuse an old completed subagent for a new unrelated task (which forces it to carry tens of thousands of stale tokens on every turn); always spawn a fresh subagent (`invoke_subagent` / `Agent`) for each distinct task.
- **Parallel Subagent Safety (Disjoint Files First):** When spawning 2+ `implementer` subagents concurrently, assign strictly non-overlapping target files (and let only the parent update `TASK_STATE.md` / `project-pitfalls.md`); use worktree isolation (`isolation: "worktree"` or `Workspace: "share"`) only when parallel tasks must touch overlapping files or run conflicting builds.
