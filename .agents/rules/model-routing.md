---
description: "(กฎคัดแยกโมเดลอัตโนมัติ Opus วางแผน ➔ Haiku สำรวจไว 15 เท่า ➔ Sonnet เขียนโค้ด/ซ่อมบั๊ก/รันเทสต์)"
---
# Automatic Model Routing & Subagent Quota Optimization

## 1. Explicit User Authorization to Spawn Subagents
The user explicitly instructs the primary orchestrator (`Opus`) to invoke the `Agent` tool with the specialized subagent types defined in `.claude/agents/*.md` (`explorer`, `implementer`, `debugger`, `reviewer`) whenever a task involves multi-step work chunks:

| Role / Subagent Type | Target Model | Max Turns | When to Invoke `Agent(...)` |
| :--- | :--- | :--- | :--- |
| **Orchestrator (Main Session)** | `opus` (or `opusplan`) | — | Architecture, user alignment (`common-ground`), decomposing tasks into `State Delta` packets, and trivial 1–2 file surgical edits. |
| **`explorer`** | `haiku` | `6` | Scanning >3 files, locating symbols/callers across directories, or mapping unknown schemas before coding. |
| **`implementer`** | `sonnet` | `15` | Multi-file code implementation (2–5 files) + running unit/widget test iterations until green. |
| **`debugger`** | `sonnet` | `10` | Investigating failing tests or runtime errors and applying at most 2 root-cause fix attempts (`2-Strike Limit`). |
| **`reviewer`** | `sonnet` | `8` | Blocker-only diff review, running full verification gates (`/verify`), or executing browser/E2E test suites. |

## 2. Anti-Quota-Drain Rules for the Primary `Opus` Window
1. **Never Run Multi-Click Browser Loops in `Opus`:** Never perform >5 interactive browser clicks (`claude-in-chrome` / `playwright`) directly in the `Opus` main session; write a deterministic CLI/Playwright test script or delegate the verification pass to `Agent(subagent_type="reviewer", model="sonnet")`.
2. **Never Spawn Subagents for Single Shell Commands:** Do not call `Agent` just to run one `git status` or read a single known file—cold-start overhead exceeds the savings. Spawn subagents only for multi-step chunks (3+ tool calls).
3. **Pass Compact `State Delta` Payloads:** When calling `Agent(...)`, pass at most 8 lines of context (target file paths + line numbers, business constraints, and exact test command).
