---
name: root-cause-debug
description: Use when encountering any bug, test failure, build error, or unexpected behavior. Enforces 4-Phase Systematic Debugging plus 0-Strike and 2-Strike circuit breakers (ใช้เมื่อแจ้งบั๊กหรือเทสต์พัง)
---
# Systematic Root-Cause Debugging (`obra/superpowers` + Circuit Breaker)

> **Reference Architecture:** [`obra/superpowers`](https://github.com/obra/superpowers) (`skills/systematic-debugging/SKILL.md`)

## 1. The Iron Law
> **NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

Randomly tweaking code ("shotgun debugging") wastes token quota and introduces new bugs. Follow these 4 phases strictly:

### Phase 1: Root Cause Investigation (`0-Strike for Missing Spec`)
1. **Read Error Messages Carefully:** Read the complete stack trace, line numbers, and error codes.
2. **Check Local Docs & Recent Changes:** Inspect the target function and check `docs/llms/` (if present).
3. **0-Strike Missing Spec Gate:**
   - If the failure occurs because a business formula, rate, or requirement is undocumented (e.g., a `TODO` or unknown magic constant), **DO NOT GUESS ANY NUMBERS**.
   - Stop immediately and output:
     ```markdown
     CIRCUIT_BREAKER: MISSING_SPEC
     - **สาเหตุ:** ฟังก์ชัน `<ชื่อฟังก์ชัน>` ใน `<ไฟล์:บรรทัด>` ต้องใช้สูตร/ข้อกำหนดทางธุรกิจที่ไม่ได้ระบุไว้
     - **ข้อมูลที่ต้องขอจากผู้ใช้:** [ระบุตัวเลขหรือเงื่อนไขที่ต้องการทราบ]
     ```

### Phase 2: Pattern Analysis
1. Locate a working example of similar logic in the codebase.
2. Compare the working code against the broken code to isolate what is different.

### Phase 3: Single-Variable Hypothesis Testing (`2-Strike Limit` & `Anti-Test-Tampering`)
- **Test-Protection Gate (`Anthropic AI-Native SDLC Stage 4`):** During a bug fix, **NEVER modify an existing test file** (`*.test.*`, `*.spec.*`, `*_test.*`, `test_*.py`) to weaken assertions or make the test pass (`protect-sensitive-files.sh` blocks tampering with existing tests during debug cycles). Always fix the root cause in the implementation code.
- **Attempt 1:** State a single hypothesis ("X fails because Y"). Apply the smallest possible `Edit` to fix Y and run **only** the failing test file.
- **Attempt 2 (If Attempt 1 fails):** Read the new error. Use `Edit` to replace Attempt 1 with Hypothesis 2 in a single step (do not waste a tool call reverting in between) and re-run the test.
- **2-Repeat Pitfall Memory (`Stage 3 Play 3.2`):** When a bug caused by a recurring project misunderstanding is resolved, append a concise 1-line rule to `## 5. Known Project Pitfalls` in `CLAUDE.md` and `AGENTS.md` so future sessions never repeat it.

### Phase 4: Hard Circuit Breaker (Stop After 2 Failed Fixes)
If Attempt 2 fails, **DO NOT attempt Fix #3**. Multiple failed fixes indicate either an architectural issue or missing context that requires human input.
1. Use `Edit` to restore the file back to its original pre-debug state (never run `git checkout` or `git restore`).
2. Output this escalation report:
   ```markdown
   CIRCUIT_BREAKER: 2_STRIKES_REACHED
   1. **สิ่งที่ลองแก้ไขไปแล้ว 2 ครั้ง:**
      - Attempt 1: [สมมติฐานที่ 1] ➔ ผลลัพธ์: [Error จริง]
      - Attempt 2: [สมมติฐานที่ 2] ➔ ผลลัพธ์: [Error จริง]
   2. **Error ล่าสุดจาก Terminal:** `[ข้อความ Error จริง]`
   3. **ทางเลือกเพื่อตัดสินใจต่อ:**
      - ทางเลือก A: [แนวทางที่ 1]
      - ทางเลือก B: [แนวทางที่ 2]
   ```

## 2. Constraints (`MUST DO` / `MUST NOT DO`)
- **MUST** read the full error message and stack trace before proposing a hypothesis.
- **MUST** stop at `0-Strike` if a business formula or rate is undocumented.
- **MUST** stop after 2 failed fix attempts (`2-Strike Limit`) and restore the file via `Edit`.
- **MUST NOT** guess magic numbers or run destructive `git checkout` / `git reset` commands.
