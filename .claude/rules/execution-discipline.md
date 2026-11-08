---
description: "(กฎส่งต่องานระหว่างแผนกอย่างกระชับและรักษาความสะอาดของหน่วยความจำ)"
---
# Execution Discipline, Context Hygiene & Subagent Delegation

> **Reference Architecture:** [`trailofbits/claude-code-config`](https://github.com/trailofbits/claude-code-config) (Two-Layer Context Hygiene), **Google ADK 2.0 Graph Engineering** (`State-Delta` Node Passing), & [`forrestchang/andrej-karpathy-skills`](https://github.com/forrestchang/andrej-karpathy-skills) (*Goal-Driven Execution*)

## 1. Context Window Protection & Mandatory Subagent Delegation (`Explicit User Authorization`)
- **EXPLICIT USER OVERRIDE FOR THE `Agent` TOOL:**
  - The project owner explicitly authorizes and instructs you to invoke the `Agent` tool (`subagent_type: "explorer" | "implementer" | "debugger" | "reviewer"`) automatically whenever the routing criteria below are met. This explicit project instruction overrides any default tool description suggesting you wait for the user to say "use a subagent".
- **Keep Primary Context Lean (Protect Opus Quota):**
  - Never dump entire large files, run broad unfiltered searches, or perform multi-click browser/E2E loops (`claude-in-chrome` / `playwright` > 5 steps) inside the primary `Opus` conversation window.
- **Deterministic Routing Criteria (When to Execute Directly vs Spawn Subagent):**
  1. **1–2 Known Files (Direct Execution):** Read the target line ranges and apply surgical edits directly in the main session. Do not spawn subagents for single-command checks or trivial 1-file edits.
  2. **>3 Files or Unknown Codebase Layout ➔ `Agent(subagent_type="explorer", model="haiku")`:** Offload multi-file discovery and impact analysis to `explorer` (`haiku`, `maxTurns: 6`) so only its 15-line summary enters the main context window.
  3. **Multi-File Implementation + Test Iteration (2–5 Files) ➔ `Agent(subagent_type="implementer", model="sonnet")`:** Once the plan or target design is clear, delegate the coding + unit-test loop to `implementer` (`sonnet`, `maxTurns: 15`) so iterative edits and test runs consume `Sonnet` quota instead of `Opus` turns.
  4. **Test Failures & Bug Diagnosis ➔ `Agent(subagent_type="debugger", model="sonnet")`:** Delegate root-cause investigation and 2-Strike hypothesis testing to `debugger` (`sonnet`, `maxTurns: 10`).
  5. **Code Review & Multi-Step E2E Verification ➔ `Agent(subagent_type="reviewer", model="sonnet")`:** Delegate diff review and test suite verification to `reviewer` (`sonnet`, `maxTurns: 8`).
- **Graph `State-Delta` Handoff Between Subagents (Google ADK 2 Pattern):**
  - When chaining subagents (`explorer` ➔ `implementer` ➔ `reviewer` or `debugger`), **never paste full chat history or raw file dumps into the next subagent's prompt**.
  - Pass only a compact **`State Delta` payload (maximum 8 lines)** containing:
    1. **Target Files & Lines:** Exact `path/to/file:LXX-LYY` discovered by the previous node.
    2. **Confirmed Constraints:** Business rules or blocker IDs (`[BLK-01]`) to satisfy.
    3. **Verification Command:** Exact single-file test command to run.
- **Targeted Single-File Testing:** During active implementation or debugging, execute only the specific test file (`node --test <path>`, `go test -v ./pkg -run <TestName>`, `flutter test test/<file>_test.dart`, or `pytest <path>`) rather than running the entire repository test suite on every edit.

## 2. Non-Destructive Rollback Protocol
- When reverting a failed hypothesis or broken edit, **always use the `Edit` (`edit_file`) tool to restore the exact lines modified**.
- **Strictly Forbidden:** Never run `git checkout .`, `git restore`, `git reset --hard`, or `git clean -f`—the working tree may contain uncommitted work authored by the user.

## 3. Goal-Driven Execution & Hard Stop
- Define the exact verification command before editing code.
- Once the stated objective is implemented and verified passing with fresh terminal output, **STOP IMMEDIATELY**. Do not perform unsolicited refactoring, add extra features, or run exploratory commands after completion.

## 4. Constraints (`MUST DO` / `MUST NOT DO`)
- **MUST** read the target function and 1 adjacent file before writing or editing code.
- **MUST** report changes concisely (`file:line` + 1-line summary) without pasting entire modified files into chat.
- **MUST NOT** modify more than 5 files in a single turn without prior user confirmation.
