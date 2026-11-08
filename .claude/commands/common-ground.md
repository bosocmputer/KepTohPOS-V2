---
description: Surface hidden assumptions, business rules, and scope boundaries before coding a new feature (สั่งถามยืนยันสมมติฐานและกฎธุรกิจให้ตรงกันก่อนเริ่มสร้างงาน)
argument-hint: [feature-request]
allowed-tools: Read, Grep, Glob
---
# /common-ground — Surface Hidden Assumptions Before Coding

Analyze the following request and establish explicit common ground before writing code:
$ARGUMENTS

## Execution Steps
1. Check `docs/llms/` (if present) and 1–2 existing project files to see what patterns and rules are already established. Do not ask about things already answered by the codebase.
2. Surface the remaining **3–4 key assumptions** in a concise bulleted list:
   - **Business Rules & Formulas:** (Rates, thresholds, limits, validation rules)
   - **Data & State Storage:** (Where data lives and how state transitions)
   - **Explicitly Out of Scope:** (What will NOT be built in this turn to prevent over-engineering)
3. Pause and wait for the user to confirm or adjust these assumptions before editing code.
