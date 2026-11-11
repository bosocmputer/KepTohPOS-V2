---
name: auto-resume-handoff
description: Use when resuming unfinished work, switching between Claude Code and Antigravity after quota exhaustion, or when .agent-last-state.log / TASK_STATE.md is present (ใช้เมื่อรับไม้ต่อหรือทำต่อจากงานที่ค้างไว้)
---
# Auto-Resume & Seamless Handoff (`Anthropic Long-Running Agent Harness` Protocol)

> **Reference Architecture:** Anthropic Engineering — *"Effective Harnesses for Long-Running Agents"* (Externalized State & Shift-Note Ritual)

## 1. The Iron Law
> **ZERO CONTEXT AMNESIA — ORIENT FROM DISK & GIT BEFORE WRITING A SINGLE LINE OF CODE.**

When switching sessions or agents (e.g., Claude Code quota hits 100% and the user switches to Antigravity, or starts a fresh session saying *"ทำต่อจากที่ค้างไว้"*), **never ask the user what they were working on**. Recover state from the workspace immediately.

## 2. Core Workflow (3-Phase Harness Ritual)

### Phase 1: Boot & Orientation Ritual (กู้คืนบริบทจากไฟล์และ Git)
1. **Read Shift Notes & State Logs:**
   - Read `.agent-last-state.log` (automatically updated on every file edit by `post-edit-format.sh`) and `TASK_STATE.md` (if present).
2. **Inspect Git History & Working Tree:**
   - Run `git log --oneline -n 5` and `git status --short` to see recently committed and uncommitted files (`M`, `??`).
   - Run `git diff` on the active file(s) to identify the exact function, line number, or `TODO` left unfinished.
3. **Run Baseline Sanity Check:**
   - Run the target test file once (`node --test <path>` or `npm test -- <path>`) *before* editing any code to verify which assertions already pass and which assertion is currently failing.

### Phase 2: Incremental Execution (ลงมือทำต่อจากจุดที่ค้าง)
1. Report the recovered state in the first 2 lines:
   > `🔄 รับไม้ต่อจากไฟล์ <ชื่อไฟล์> (พบงานค้างที่ฟังก์ชัน <ชื่อฟังก์ชัน> — เทสต์ปัจจุบันผ่าน X/Y ข้อ กำลังทำต่อทันที)`
2. Complete only the remaining unfinished logic following `code-simplicity.md` without rewriting already-passing functions.
3. Verify the completed work via `verification-before-completion`.

### Phase 3: Continuous Handoff / Shift-Note Ritual (ทุกครั้งที่จบงานย่อย หรือเมื่อสั่ง `/handoff`)
Update the top summary section of `TASK_STATE.md` (`<= 20` lines above `## 🔄 Auto-Synced Git & Session State`) at the end of **every completed task** (do not wait for `/handoff`), then run `bash .claude/hooks/audit-session-proof.sh --brief` so the script automatically appends the live Git branch, latest 5 commits, working tree, and checkpoint:
- **Completed:** Files and functions verified passing.
- **In Progress / Broken:** Exact `file:line` and current error output (if any).
- **Next Immediate Step:** The single exact action the next session should take first.

## 3. Constraints (`MUST DO` / `MUST NOT DO`)
- **MUST** read `.agent-last-state.log` and `git diff` before asking the user any question.
- **MUST** run the existing test suite before making new edits so you do not break working baseline code.
- **MUST NOT** redo or refactor code that the previous session already completed and tested.
