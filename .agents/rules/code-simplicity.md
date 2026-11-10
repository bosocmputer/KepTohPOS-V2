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
# Karpathy Surgical Coding Invariants (`forrestchang/andrej-karpathy-skills`)

1. **Think Before Coding (Zero Silent Assumptions):**
   - If a business rule, tax/discount formula, or constraint is unstated, stop (`CIRCUIT_BREAKER: MISSING_SPEC`) and ask—never guess.
   - If a simpler approach exists than what was asked, state it briefly.
2. **Simplicity First (No Speculative Abstractions):**
   - Write the minimum code required to solve the stated problem.
   - No helpers, factories, base classes, or config flags for single-use logic.
3. **Surgical Changes Only:**
   - Every changed line in `git diff` must trace directly to the user's request.
   - Do not reformat unrelated lines, rename adjacent variables, or delete pre-existing dead code unless asked.
   - Remove only imports/variables made unused by your own edit.
4. **No Unrequested Artifacts:**
   - Never create unrequested documentation or summary files (`SUMMARY.md`, `NOTES.md`, etc.).
