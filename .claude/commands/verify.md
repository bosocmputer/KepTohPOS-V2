---
description: Execute the 5-step Gate Function and 3-tier verification (Unit Test, Typecheck/Build, Runtime Smoke Check) (สั่งรันเทสต์พิสูจน์ผลลัพธ์จริง 3 ระดับก่อนจบงาน)
argument-hint: [target-test-or-module]
allowed-tools: Agent, Read, Grep, Glob, Bash
---
# /verify — Evidence-Based Verification Gate (`obra/superpowers`)

Run the mandatory **Verification Gate Function** (for multi-suite or E2E verification, offload to `Agent(subagent_type="reviewer", model="sonnet")` to save primary `Opus` quota) for: $ARGUMENTS

## The 5-Step Gate Function
1. **IDENTIFY:** Determine the exact commands that prove the recent changes work.
2. **RUN:** Execute the fresh commands now (matching the project stack):
   - **Tier 1 (Unit/Widget Test):** `node --test <path>` / `npm test -- <path>` (JS/TS) | `go test -v ./pkg` (Go) | `flutter test test/<file>_test.dart` (Flutter) | `pytest <path>` (Python) | `cargo test` (Rust)
   - **Tier 2 (Typecheck/Analyze/Build):** `npx tsc --noEmit` (TS) | `go vet ./...` (Go) | `flutter analyze` (Flutter) | `ruff check .` (Python) | `cargo check` (Rust)
   - **Tier 3 (Non-Blocking Smoke Check):** Check active ports via `lsof -i :<port>` and test via `curl -s -i` (never run `npm run dev`, `go run`, or `flutter run` in the foreground).
3. **READ:** Inspect the full terminal output, exit code, and pass/fail counts.
4. **VERIFY:** Confirm whether the output actually proves the claim.
5. **REPORT, NEXT STEPS & SESSION PROOF:** Output the exact command run and actual terminal result, explicitly stating any tier that was not run, include a concise `### ⏭️ ขั้นตอนถัดไป (Next Steps)` (1–3 bullets), then run `bash .claude/hooks/audit-session-proof.sh --brief` and append the 4-line `### 📊 ผลชี้วัด Agent Guard Template` block to the end of your reply.
