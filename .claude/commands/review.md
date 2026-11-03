---
description: Run a pragmatic Blocker-Only code and security review capped at 2 convergence rounds
argument-hint: [optional-file-or-diff-scope]
allowed-tools: Read, Edit, Grep, Glob, Bash
---
# /review — Convergent Code & Security Review (Max 2 Rounds)

Delegate to the `reviewer` sub-agent (or apply the `pragmatic-review` skill) to inspect recent changes (`git diff` $ARGUMENTS):

## Convergence Protocol
1. **Round 1 (Blocker-Only Scan):**
   - Flag ONLY `[BLOCKER]` defects (broken logic, calculation bugs, security vulnerabilities, data loss). Ignore stylistic nitpicks.
   - If no blockers exist, output `VERDICT: APPROVE` and stop immediately.
2. **Surgical Repair (If `CHANGES_REQUESTED`):**
   - Fix only the flagged `[BLK-XX]` items using minimal edits.
3. **Round 2 (Final Verification & Scope Freeze):**
   - Verify that Round 1 blockers are resolved and run the relevant test file once to confirm zero regressions.
   - Do not raise new issues in untouched code. Output `VERDICT: APPROVE` (or `VERDICT: ESCALATE_TO_USER` if deadlocked).
