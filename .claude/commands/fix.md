---
description: Diagnose and fix bugs systematically using 0-Strike missing-spec detection and a 2-Strike circuit breaker
argument-hint: [bug-description-or-failing-test]
allowed-tools: Read, Edit, Grep, Glob, Bash
---
# /fix — Systematic Root-Cause Repair (Max 2 Attempts)

Delegate to the `debugger` sub-agent (or apply the `root-cause-debug` skill) to resolve:
$ARGUMENTS

## Mandatory Guardrails
1. **No Fixes Without Root Cause First:** Read the full stack trace and target lines before making any edit.
2. **0-Strike for Missing Spec:** If the failure stems from an undocumented business formula or missing requirement, stop immediately (`CIRCUIT_BREAKER: MISSING_SPEC`) and ask the user.
3. **2-Strike Ceiling:** Attempt at most **2 targeted fixes**, running only the relevant test file after each attempt.
4. **Safe Revert on Strike 2:** If Attempt 2 fails, use `Edit` to restore the original code (never use `git checkout`/`git restore`) and output `CIRCUIT_BREAKER: 2_STRIKES_REACHED` with options for the user.
