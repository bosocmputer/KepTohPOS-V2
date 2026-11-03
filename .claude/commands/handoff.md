---
description: Save compact task state to TASK_STATE.md before running /clear or switching between Claude Code and Antigravity
argument-hint: [optional-notes]
allowed-tools: Read, Write, Edit, Bash
---
# /handoff — Seamless Session & Cross-Agent State Handoff

Write a compact state checkpoint to `TASK_STATE.md` (maximum 15 lines) so a fresh session or another agent (Antigravity / Claude Code) can resume with zero context loss:
$ARGUMENTS

## Required `TASK_STATE.md` Structure
```markdown
# Active Task Handoff State
- **Objective:** [1-sentence goal of current feature/fix]
- **Completed & Verified:**
  - `path/to/file`: [What is done + passing test command]
- **Next Immediate Step:**
  - `path/to/file:LXX`: [Exact function or bug remaining]
- **Known Constraints / Decisions:**
  - [Key business rules or user decisions established in this session]
```
After writing `TASK_STATE.md`, inform the user they can now run `/clear` or switch to the other agent and type *"ทำต่อจากที่ค้างไว้"*.
