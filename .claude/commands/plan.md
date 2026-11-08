---
description: Analyze task complexity and create a concise, read-only implementation plan before writing code (สั่งวิเคราะห์งานและวางแผนโครงสร้างไม่เกิน 10 บรรทัดก่อนเริ่มลงมือทำ)
argument-hint: [feature-or-task-description]
allowed-tools: Agent, Read, Grep, Glob
---
# /plan — Task Triage & Concise Architecture Plan

Evaluate the following task using the **Task Triage** rules:
$ARGUMENTS

## Execution Steps
1. **Trivial Check (1–2 files, unambiguous):**
   - If the change is localized and obvious, state in 2 lines which file/function needs updating and tell the user it is ready for direct surgical implementation without ceremony.
2. **Complex Task (>3 files or architectural impact):**
   - **Mandatory Subagent Exploration:** Invoke `Agent(subagent_type="explorer", model="haiku")` to locate the target files, callers, and existing test patterns so exploratory file reads stay out of the main `Opus` context window.
   - Output a structured plan (**maximum 12 lines**):
     - **Assumptions & Tradeoffs:** (Surface any ambiguity upfront per Karpathy's *Think Before Coding*)
     - **Files to Modify/Create:** (`path/to/file` — 1-line purpose)
     - **Subagent Execution Plan:** Specify which chunks will be delegated to `Agent(subagent_type="implementer", model="sonnet")` and `Agent(subagent_type="reviewer", model="sonnet")`.
     - **Verification Command:** (Exact test/build command to prove completion)
   - Wait for user confirmation before modifying any files.
