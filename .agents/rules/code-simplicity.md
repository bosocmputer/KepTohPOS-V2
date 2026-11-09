---
description: "(กฎเขียนโค้ดให้เรียบง่ายที่สุด แก้เฉพาะจุด ไม่สร้างความซับซ้อนเกินจำเป็น)"
paths:
  - "**/src/**"
  - "**/app/**"
  - "**/lib/**"
  - "**/supabase/**"
  - "**/packages/**"
  - "**/cmd/**"
  - "**/internal/**"
  - "**/pkg/**"
  - "**/scripts/**"
---
# Karpathy Coding Guidelines (`forrestchang/andrej-karpathy-skills`)

Behavioral principles to reduce common LLM coding mistakes: overcomplicating code, making silent assumptions, and editing unrelated lines.

## 1. Think Before Coding
**Don't assume. Don't hide confusion. Surface tradeoffs.**
- State your assumptions explicitly. If uncertain about a business rule or formula, ask rather than guessing.
- If multiple interpretations exist, present them briefly—do not pick silently.
- If a simpler approach exists than what was asked, say so.

## 2. Simplicity First
**Minimum code that solves the problem. Nothing speculative.**
- No features beyond what was asked.
- No abstractions (helpers, factories, base classes) for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- **Self-Check:** If 200 lines could be 50, rewrite it. Ask: *"Would a senior engineer say this is overcomplicated?"*

## 3. Surgical Changes
**Touch only what you must. Clean up only your own mess.**
- When editing existing code:
  - Do NOT "improve" adjacent code, comments, or formatting (No Drive-by Refactoring).
  - Do NOT refactor systems that aren't broken.
  - Match existing project style, imports, and conventions even if you'd do it differently.
- Remove imports/variables/functions that **your own changes** made unused, but do NOT delete pre-existing dead code unless asked.
- **The Test:** Every changed line in `git diff` must trace directly to the user's request.

## 4. Goal-Driven Execution
**Define success criteria. Loop until verified.**
- Transform tasks into verifiable goals:
  - *"Add validation"* ➔ Write tests for invalid inputs, then make them pass.
  - *"Fix the bug"* ➔ Write a test that reproduces it, then make it pass.
- Never create unrequested documentation files (`SUMMARY.md`, `NOTES.md`, etc.).
