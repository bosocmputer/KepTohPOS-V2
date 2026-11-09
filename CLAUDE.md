# Project Overview & Universal Agent Governance (Claude Code)
> **Communication Mandate:** Always respond to the user in **Thai (ภาษาไทย)**, keeping technical terms, file paths, commands, and code identifiers in English.
> **Upstream Architectures:** [`anthropics/skills`](https://github.com/anthropics/skills) • [Anthropic AI-Native SDLC Playbook](https://claude.com/resources/articles/the-ai-native-sdlc-playbook) • [`cloudflare/security-audit-skill`](https://github.com/cloudflare/security-audit-skill) • [`andrej-karpathy-skills`](https://github.com/forrestchang/andrej-karpathy-skills) • [`obra/superpowers`](https://github.com/obra/superpowers) • [`garrytan/gstack`](https://github.com/garrytan/gstack) • [`jeffallan/claude-skills`](https://github.com/jeffallan/claude-skills) • [`supabase/agent-skills`](https://github.com/supabase/agent-skills) • [`trailofbits/claude-code-config`](https://github.com/trailofbits/claude-code-config) • [`heydamir/unslop`](https://github.com/heydamir/unslop) • [`mrdoob/three.js`](https://github.com/mrdoob/three.js)

## 0. Auto-Detect Tech Stack & Quick Commands
Inspect root manifest files (including monorepo subfolders such as `app/`, `supabase/`, `packages/`) to select the exact Tier 1 and Tier 2 verification commands:

| Tech Stack / Manifest | Tier 1: Single-File Test (Run after every edit) | Tier 2: Typecheck / Analyze / Build |
| :--- | :--- | :--- |
| **Node.js / TypeScript** (`package.json`) | `node --test <path>` or `npm test -- <path>` | `npx tsc --noEmit` \| `npm run build` |
| **Go (Golang)** (`go.mod`) | `go test -v ./path/to/pkg -run <TestName>` | `go vet ./...` \| `go build ./...` |
| **Flutter / Dart** (`pubspec.yaml` / `app/pubspec.yaml`) | `flutter test test/<file>_test.dart` | `flutter analyze` |
| **Supabase / PostgreSQL** (`supabase/config.toml`) | `supabase test db` (local Docker pgTAP) | `supabase db reset` (local Docker only) |
| **Python** (`pyproject.toml` / `requirements.txt`) | `pytest <path/to/test_file.py>` | `ruff check .` \| `mypy .` |
| **Rust** (`Cargo.toml`) | `cargo test <test_name>` | `cargo check` \| `cargo clippy` |

- **Dev Server / App Runner:** Never run long-lived foreground servers (`npm run dev`, `go run`, `flutter run`) in the agent shell; check ports via `lsof -i :<port>` instead.
- **Local Framework Docs (`llms.txt`):** If `docs/llms/` or `llms.txt` exists in the repo, read it first instead of spawning heavy external documentation searches.

---

## 1. Zero-Command Auto-Routing & Explicit Subagent Delegation
> **EXPLICIT USER AUTHORIZATION (OVERRIDES DEFAULT `Agent` TOOL HESITATION):**
> The project owner explicitly mandates that the main `Opus` session act as a **Lead Orchestrator** and **proactively invoke the `Agent` tool (`explorer`, `implementer`, `debugger`, `reviewer`) with the designated `model` tier below** whenever a task spans multiple files or steps, preserving main-window context and `Opus` quota:

| User Request / Task Pattern | Scope | Mandatory Subagent (`Agent` Tool) & Model Routing |
| :--- | :--- | :--- |
| **"โปรเจกต์นี้ใช้ React / NestJS / สร้าง PDF / MCP..."** | Stack setup / Skill install | Load `tech-stack-skills` and install 2–4 matching skills via `bash .claude/hooks/install-skill.sh` |
| **"ทำต่อจากที่ค้างไว้ / โควต้าอีกฝั่งหมด"** | Cross-agent handoff | Load `auto-resume-handoff`, inspect `.agent-last-state.log` + `git status` + `TASK_STATE.md` (if present), and resume immediately |
| **"สร้างระบบ... / เพิ่มฟีเจอร์..." (Broad/Ambiguous)** | Architectural / Multi-option | Load `common-ground` and confirm 3–4 concise assumptions in Thai before writing code |
| **Trivial Edit (1–2 known files)** | **Trivial Task (1–2 files)** | Execute directly in the main window via surgical `Edit` + Tier 1 single-file test (do NOT spawn subagents for 1–2 file edits) |
| **Unfamiliar codebase search / tracing (>3 files)** | **Multi-File Exploration** | `Agent(subagent_type="explorer", model="haiku")` — returns exact `file:line` coordinates and signatures |
| **Multi-file implementation (2–5 files) + unit tests** | **Multi-Step Implementation** | `Agent(subagent_type="implementer", model="sonnet")` — applies surgical edits and runs Tier 1 tests |
| **"เทสต์พัง / บั๊กหน้า... / Error..." (Bug investigation)** | **Root-Cause Debugging** | `Agent(subagent_type="debugger", model="sonnet")` — enforces 2-Strike limit and `Verify RED ➔ GREEN` |
| **"ช่วยตรวจโค้ด / รีวิว / รันชุดทดสอบ E2E"** | **QA Review & E2E Suite** | `Agent(subagent_type="reviewer", model="sonnet")` — runs `git diff` review, Tier 2 checks, and E2E suites |
| **"ตรวจความปลอดภัย / `/security-audit` / เช็ก RLS & RPC"** | **Security Audit (Cloudflare Gate)** | Load `security-audit`: spawn `explorer` (`haiku`) to map attack surface + `reviewer` (`sonnet`) to trace `entrypoint ➔ sink` (`[CONFIRMED]` vs `[NEEDS_VALIDATION]`) |
| **"สร้าง 3D Viewer / Three.js / WebGL"** | Web 3D Visualization | Load `threejs-expert` (`mrdoob/three.js r187+`: `three/addons/*`, `HDRLoader`, `OutputPass`, `dispose()`) |
| **"เปิดจอ 3D / เช็กหลักฐานโมเดล"** | 3D HUD / Session Proof | Run `bash .claude/hooks/open-hud.sh` (3D Monitor) or `bash .claude/hooks/audit-session-proof.sh` (`.jsonl` model audit) |

---

## 2. Anti-Loop & Quota Protection Guardrails
1. **0-Strike for Missing Business Spec:**
   - If a task requires an unstated business formula, discount rule, tax rate, or organization-specific constant not found in code or `docs/llms/`, **never guess or invent numbers**. Emit `CIRCUIT_BREAKER: MISSING_SPEC` and ask the user immediately.
2. **2-Strike Technical Bug Limit:**
   - When fixing a technical bug or failing test, if **2 consecutive fix attempts** still fail verification, **STOP immediately**.
   - Revert uncommitted experimental edits back to a clean state via `Edit` and emit `CIRCUIT_BREAKER: 2_STRIKES_REACHED` summarizing both attempts and presenting clear options in Thai.
3. **Targeted Exploration Only:**
   - Use scoped `Grep` and `Glob` queries. Never read entire directory trees blindly.
   - Before creating a new file, read 1 existing sibling file to match naming, imports, and library conventions.
4. **Execution Ceiling:**
   - Do not modify more than 5 files in a single turn without confirming the file list with the user first.

---

## 3. Integrity, Git Safety & Security Rules
1. **Gate Integrity & Anti-Reward-Hacking (`garrytan/gstack RH-1..RH-16 & PL-2`):**
   - Never weaken `expect`/`assert` conditions, delete failing tests, add `.skip` / `.only` (`RH-1`), or inflate timeouts/thresholds (`RH-15`) to force a green run.
   - Never branch on `process.env.NODE_ENV === 'test'` or `process.env.CI` inside production logic to bypass validation (`RH-12`).
   - Never add `@ts-ignore`, `@ts-expect-error`, `eslint-disable`, `# type: ignore`, or `// nolint` to silence errors (`RH-13`).
   - **Zero-Run Green (`PL-2`):** A test command exiting `0` with `0 tests ran` is a **FAILED** verification. Fix the test path/filter until `tests_ran >= 1`.
2. **Git, Dependency & Production Release Gate (`Anthropic AI-Native SDLC Stage 5`):**
   - Never run `git checkout .`, `git checkout -- <file>`, `git checkout <filepath>`, `git restore`, `git reset --hard`, `git clean -f`, `git switch -f`, or `git push --force` / `+main` (enforced by `validate-bash.sh`). Branch creation (`git checkout -b <branch>`, `git switch -c <branch>`) and switching branches (`git checkout <branch>`, `git switch <branch>`) are allowed.
   - Never install new packages (`npm install <pkg>`, `pnpm add`, `flutter pub add`, `go get`, `pip install`, `cargo add`) without user approval. Once approved in chat, prefix the command with `DEPS_APPROVED=1`.
   - **Production Deploy & Remote DB Gate:** Never deploy to production (`vercel --prod`, `firebase deploy`, `wrangler deploy`, `fly deploy`) or push migrations to a remote/linked database (`prisma migrate deploy`, `supabase db push`, `supabase db reset --linked`, `terraform apply`, `kubectl apply`) without user approval. Local Docker resets (`supabase db reset` without `--linked`/`--db-url`) are allowed for local testing. Once remote deploy/push is approved, prefix with `RELEASE_APPROVED=1`.
   - **Anti-Test-Tampering (`Stage 4`):** While debugging (`strikeCount >= 1`), `protect-sensitive-files.sh` blocks edits to existing test files (`exit 2`) so fixes must target production root causes.
3. **Secrets & Database Protection:**
   - Never read, edit, output, or commit `.env*`, `*.key`, `*.pem`, `*.keystore`, `*.jks`, `*.p12`, `*.sqlite`, or `*.db` files (inspect `.env.example` instead).

---

## 4. Evidence-Based Reporting (No Over-Claiming) & Session Proof Summary
- Report only what was actually executed and verified in the current turn, citing the **exact command run** and **real terminal output**.
- Explicitly state **"ยังไม่ได้รันทดสอบ"** for anything not executed (e.g., server not running or E2E skipped).
- Never use exaggerated claims such as `"เสร็จสมบูรณ์ 100%"`, `"สมบูรณ์แบบ"`, or `"ไม่มีบั๊กแน่นอน"`.
- **End-of-Task / Milestone Session Proof Report:** Whenever finishing a milestone, merging a PR, or running `/verify` or `/handoff` (do NOT run on trivial mid-task turns), execute `bash .claude/hooks/audit-session-proof.sh --brief` and include its 3-line `### 📊 ผลชี้วัด Agent Guard Template` output at the bottom of your final response.

---

## 5. Known Project Pitfalls (`Anthropic SDLC Playbook Stage 3 — 2-Repeat Memory`)
> **Persistence Rule (Survives Template `rsync` Upgrades):**
> Whenever the agent repeats the same project-specific mistake a 2nd time, append a concise 1-line rule to **`.claude/rules/project-pitfalls.md`** (and mirror to `.agents/rules/project-pitfalls.md`). Template `rsync` updates exclude `project-pitfalls.md` so project-specific lessons are never overwritten.
- Never weaken or edit existing test assertions (`expect`/`assert`) to make a failing test pass; fix the root cause in production code.
- When modifying rules or skills in `.claude/`, always keep `.agents/` synchronized for seamless Claude Code ↔ Antigravity handoffs.
