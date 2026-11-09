---
description: Distill a bug root cause, resolved [BLOCKER], or user correction into a 1-line rule in project-pitfalls.md (สกัดบทเรียนและข้อตกลงเฉพาะโปรเจกต์เก็บเข้าความจำถาวร)
argument-hint: [lesson-or-correction-to-remember]
allowed-tools: Read, Edit, Write
---
# /learn — Project-Specific Pitfall & Convention Distillation

Distill the lesson, resolved `[BLOCKER]`, or user correction from `$ARGUMENTS` (or from the most recent bug fix / review in this session if `$ARGUMENTS` is empty) into permanent project memory:

## Execution Steps
1. **Read Existing Memory:** Read `.claude/rules/project-pitfalls.md` to check existing rules and avoid duplicates.
2. **Distill into 1 Concise Line:** Format the rule strictly as:
   `- **[Category]:** <What to always do / never do in this project + concise reason>`
3. **Enforce Anti-Bloat Cap (Max 30 Rules):**
   - If a similar rule already exists, update that single line instead of adding a duplicate.
   - If the file already has 30 rules, merge the 2 most closely related rules so the file never exceeds 30 lines of rules.
4. **Dual-Engine Sync:** Apply the exact same update to both `.claude/rules/project-pitfalls.md` and `.agents/rules/project-pitfalls.md`.
5. **Confirm in Thai:** Report the exact 1-line rule added/updated and the current rule count (`X/30`).
