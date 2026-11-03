---
name: pragmatic-review
description: Use when reviewing code changes or diffs for logic bugs and security vulnerabilities using a Blocker-Only policy capped at 2 rounds (ใช้เมื่อต้องการตรวจรีวิวโค้ดเฉพาะจุดที่เป็น Blocker ไม่เกิน 2 รอบ)
---
# Pragmatic Code Review & Convergence Gate (`obra/superpowers` Review Protocol)

> **Reference Architecture:** [`obra/superpowers`](https://github.com/obra/superpowers) (`requesting-code-review/SKILL.md` & `receiving-code-review/SKILL.md`)

## 1. The Iron Law
> **TECHNICAL CORRECTNESS OVER SOCIAL COMFORT — REPORT BLOCKERS ONLY, CONVERGE IN AT MOST 2 ROUNDS.**

## 2. Core Workflow

### Step 1: Diff Inspection (`requesting-code-review` Protocol)
1. Inspect exact changes using `git status --short` and `git diff` (or `git diff BASE_SHA..HEAD_SHA`).
2. Read the surrounding context of modified functions to verify data contracts, input validation, and error handling.

### Step 2: Severity Triage (`Blocker-Only Policy`)
Categorize findings strictly and **report only `[BLOCKER]` items**:

#### 🔴 Report Immediately (`[BLOCKER]`):
1. **Broken Logic & Edge Cases:** Incorrect calculations, unhandled `null`/`undefined`/`NaN`, off-by-one errors, or broken idempotency (double-submit bug).
2. **Security Vulnerabilities:** Missing authentication/authorization (IDOR), SQL/Command Injection, XSS, or leaked secrets/PII in logs or responses.
3. **Data Corruption & Race Conditions:** Missing database transactions, check-then-act race conditions (e.g., double booking or negative stock).
4. **Severe Performance Defects:** N+1 queries inside loops, unbounded `SELECT *`, or memory leaks.

#### ⚪ Suppress Completely (Ignore Nitpicks):
- Formatting, indentation, or semicolon style (handled by Prettier/Linters).
- Subjective variable naming or personal stylistic preferences that do not affect correctness.

### Step 3: Receiving & Applying Review (`receiving-code-review` Protocol)
- **No Hollow Praise:** Skip conversational filler (*"You're absolutely right!"* or *"Great catch!"*).
- **Verify Before Changing:** Trace each reported `[BLOCKER]` against the actual code contract, apply the surgical fix, and run the test suite.

### Step 4: Convergence Circuit Breaker (`MAX_ROUNDS = 2`)
- **Round 1 of 2:** Report all `[BLOCKER]` defects found in the current diff.
- **Round 2 of 2 (`No Moving Goalposts`):** Verify **only** whether Round 1 `[BLOCKER]` items were resolved and whether tests pass. Never invent new critiques on untouched code in Round 2.

## 3. Constraints (`MUST DO` / `MUST NOT DO`)
- **MUST** run the relevant test file to verify behavior before issuing `VERDICT: APPROVE`.
- **MUST** include exact `file:line` references and a concrete fix for every `[BLOCKER]`.
- **MUST NOT** nitpick code style, formatting, or suggest unsolicited architectural rewrites.
- **MUST NOT** exceed 2 review rounds; if unresolved after Round 2, output `VERDICT: ESCALATE_TO_USER`.

## 4. Required Verdict Output Format
```markdown
VERDICT: APPROVE
- ตรวจสอบ `git diff` และรันเทสต์ยืนยันเรียบร้อยแล้ว ไม่พบปัญหาในระดับ Blocker
```
*(Or when blockers exist:)*
```markdown
VERDICT: CHANGES_REQUESTED
- **[BLK-01] [Security / Logic / Race Condition] (`path/to/file.ts:L42`)**
  - **ปัญหา:** [ระบุสาเหตุที่ทำให้พังหรือเกิดช่องโหว่]
  - **วิธีแก้:** [ระบุโค้ดหรือเงื่อนไขที่ต้องแก้ให้ชัดเจน]
```
