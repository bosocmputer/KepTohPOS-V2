---
description: "(กฎส่งต่องานระหว่างแผนกอย่างกระชับและรักษาความสะอาดของหน่วยความจำ)"
---
# Execution Discipline & Non-Destructive Rollback

## 1. Compact `State-Delta` Handoff & Fresh Subagents per Task
- When chaining subagents (`explorer` ➔ `implementer` ➔ `reviewer` / `debugger`), never paste full chat history or raw file dumps.
- Pass at most an **8-line `State Delta` payload**: (1) exact `path/to/file:LXX-LYY`, (2) confirmed business rules or blocker IDs (`[BLK-01]`), and (3) exact Tier 1 test command.
- **Never Reuse Old Subagents Across Unrelated Tasks:** Once a subagent completes a task, do not `send_message` to reuse that same subagent for a new unrelated user request (reusing an old subagent carries its entire prior context on every turn, causing severe slowdowns and token bloat). Spawn a fresh subagent (`invoke_subagent` / `Agent`) for each new task.

## 2. Non-Destructive Rollback Protocol
- When reverting a failed hypothesis or broken edit, **always use `Edit` (`edit_file`) to restore the exact lines modified**.
- **Strictly Forbidden:** Never run `git checkout .`, `git checkout -- <file>`, `git restore`, `git reset --hard`, or `git clean -f`—the working tree may contain uncommitted user work.

## 3. Goal-Driven Execution & Hard Stop
- Read the target function and 1 adjacent sibling file before editing.
- During active coding/debugging, run only the single target test file (Tier 1) rather than the full repository suite on every edit.
- Once the stated objective passes verification with fresh terminal output, **STOP IMMEDIATELY**. Do not perform unsolicited refactoring or add unrequested files.
- Do not modify more than 5 files in a single turn without confirming the file list with the user first.
