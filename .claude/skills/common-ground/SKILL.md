---
name: common-ground
description: Use when building a new feature or module with ambiguous requirements or multiple design choices to surface hidden assumptions before writing code (ใช้เมื่อสั่งสร้างฟีเจอร์ใหม่ที่มีจุดกำกวมเพื่อเคลียร์สมมติฐานก่อนเขียนโค้ด)
---
# Common Ground & Pre-Code Discovery (`obra/superpowers` Brainstorming + Karpathy Principle #1)

> **Reference Architecture:** [`obra/superpowers`](https://github.com/obra/superpowers) (`skills/brainstorming/SKILL.md`) & [`forrestchang/andrej-karpathy-skills`](https://github.com/forrestchang/andrej-karpathy-skills) (*Think Before Coding*)

## 1. The Iron Law
> **NO CODE WITHOUT REQUIREMENT CLARITY FIRST — NEVER SILENTLY GUESS BUSINESS RULES.**

When asked to build a new feature or modify behavior where business rules, formulas, or architectural choices are ambiguous, **do not jump straight into generating code**.

## 2. Core Workflow

### Step 1: Silent Codebase Pre-Check (สำรวจโค้ดเดิมก่อนถาม)
1. Check `docs/llms/` or `llms.txt` (if present) for documented domain rules.
2. Inspect 1–2 adjacent files in the repository to learn existing conventions (storage pattern, validation library, error format).
3. **Never ask the user about patterns that are already answered in the codebase.** Follow existing conventions automatically.

### Step 2: Socratic Assumption Surfacing (`obra/superpowers` Protocol)
If critical business rules are still missing after Step 1, surface at most **3–4 concise points**:
- **Business Rules & Formulas:** Calculation rates, thresholds, time limits, or status transitions.
- **Data & Persistence:** Where state lives (existing table, new migration, or in-memory).
- **Trade-off Options (if multiple valid designs exist):** Present `Option A` (simplest) vs `Option B` (more flexible) in 1 line each.
- **YAGNI Scope Boundary (`Out of Scope`):** Explicitly list what you will *not* build in this turn to prevent bloat.

### Step 3: Wait for Confirmation (or Proceed if Unambiguous)
- If a business number/formula is missing, stop and wait for user confirmation.

## 3. Constraints (`MUST DO` / `MUST NOT DO`)
- **MUST** check 1–2 existing project files before formulating questions.
- **MUST** keep the Common Ground summary under 10 lines.
- **MUST NOT** invent business rates, discount percentages, or policy rules out of thin air.
- **MUST NOT** write a 100-line formal specification document when a 6-line bullet list suffices.

## 4. Standard Output Format
```markdown
### 🤝 ตรวจสอบความเข้าใจตรงกัน (Common Ground)
1. **กฎธุรกิจ/การคำนวณ:** [ระบุสิ่งที่เข้าใจ หรือคำถามสั้นๆ หากยังไม่มีตัวเลขระบุ]
2. **การจัดเก็บข้อมูลและโครงสร้าง:** [อ้างอิงตามโค้ดเดิมในโปรเจกต์ หรือเสนอทางเลือก A vs B]
3. **ขอบเขตที่ยังไม่ทำในรอบนี้ (YAGNI):** [ระบุสิ่งที่ตัดออกเพื่อไม่ให้โค้ดบวม]

หากถูกต้องตามนี้ แจ้งยืนยันหรือปรับแก้ได้เลยครับ
```
