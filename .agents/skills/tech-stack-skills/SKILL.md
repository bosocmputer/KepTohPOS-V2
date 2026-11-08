---
name: tech-stack-skills
description: Use when initializing a project, declaring the project tech stack, or installing official Anthropic skills (anthropics/skills) or framework-specific skills (jeffallan/claude-skills) into both Claude Code and Antigravity IDE (ใช้เมื่อเริ่มโปรเจกต์ใหม่หรือต้องการดึง Skill เฉพาะทางมาติดตั้ง)
---
# On-Demand Dual-Engine Skill Installer (`anthropics/skills` + `jeffallan/claude-skills` + `heydamir/unslop`)

> **Reference Architectures:**
> - [`anthropics/skills`](https://github.com/anthropics/skills) (19 Official Anthropic Agent Skills — UI, Playwright Testing, MCP v2, Claude API, Office/PDF Suite)
> - [`jeffallan/claude-skills`](https://github.com/jeffallan/claude-skills) (67 Specialized Tech-Stack Skills with Progressive `SKILL.md` + `references/` Routing)
> - [`heydamir/unslop`](https://github.com/heydamir/unslop) (UI Anti-Slop Audit Skill)

## 1. The Iron Law
> **PROGRESSIVE DISCLOSURE — CHERRY-PICK 2–4 SKILLS MAX PER PROJECT, NEVER BULK-INSTALL ALL SKILLS AT ONCE.**

Every installed skill's `name` and `description` are loaded into the agent's system prompt at startup. Installing dozens of unused skills wastes context window tokens every turn. Install **only the 2–4 skills that match the active repository's tech stack or task**.

## 2. Official `anthropics/skills` Catalog (19 Verified Folder Names)

| Category | Verified Skill Names (`github.com/anthropics/skills`) |
| :--- | :--- |
| **UI, Frontend & Web Artifacts** | `frontend-design` *(Studio-grade UI & 5 AI-Tell elimination)*, `web-artifacts-builder` *(React + Tailwind + shadcn/ui bundler)*, `theme-factory`, `canvas-design`, `algorithmic-art`, `brand-guidelines` |
| **QA, Testing & Agent Engineering** | `webapp-testing` *(Playwright + `with_server.py` lifecycle)*, `mcp-builder` *(MCP TypeScript SDK v2 & Python FastMCP)*, `claude-api` *(Claude SDKs & Managed Agents)*, `skill-creator` *(Skill eval & benchmark harness)* |
| **Production Document Suite (Apache 2.0)** | `pdf` *(pypdf/pdfplumber/reportlab/OCR/forms)*, `docx` *(docx-js + XML tracked redlines)*, `xlsx` *(openpyxl + LibreOffice `recalc.py`)*, `pptx` *(pptxgenjs + 3-tier visual QA)* |
| **Workflows, Comms & Fluency** | `doc-coauthoring` *(3-stage PRD/RFC workflow)*, `internal-comms`, `slack-gif-creator`, `academy-guide`, `discernment-nudge` |

## 3. Official `jeffallan/claude-skills` & `heydamir/unslop` Catalog

| Project Layer | Verified Skill Names (`jeffallan/claude-skills` & `heydamir/unslop`) |
| :--- | :--- |
| **Frontend, Mobile & UI Polish** | `react-expert`, `nextjs-developer`, `vue-expert`, `angular-architect`, `tailwind-expert`, `react-native-expert`, `flutter-expert`, `unslop` |
| **Backend Frameworks** | `nestjs-expert`, `fastapi-expert`, `django-expert`, `laravel-specialist`, `spring-boot-engineer`, `rails-expert`, `dotnet-core-expert` |
| **Core Languages** | `typescript-pro`, `python-pro`, `golang-pro`, `rust-engineer`, `java-architect`, `cpp-pro`, `csharp-developer` |
| **Database & API** | `postgres-pro`, `sql-pro`, `database-architect`, `graphql-architect`, `api-designer`, `microservices-architect` |
| **Testing & Quality** | `playwright-expert`, `test-master`, `fullstack-guardian`, `code-reviewer`, `debugging-wizard` |
| **Security & DevOps** | `security-reviewer`, `secure-code-guardian`, `devops-engineer`, `kubernetes-specialist`, `terraform-engineer`, `cloud-architect` |

## 4. Core Workflow (Dual-Engine Sparse Installation for Claude Code & Antigravity)

1. **Detect Stack or Capability Need:** Check `package.json`, `pyproject.toml`, `go.mod`, or `Cargo.toml` (or read the user's prompt) to identify the 2–4 relevant skills.
2. **Execute Sparse Installer:** Run the built-in sparse-checkout installer script:
   ```bash
   bash .claude/hooks/install-skill.sh <skill-1> <skill-2>
   ```
   *(The script automatically detects whether each skill belongs to `anthropics/skills`, `jeffallan/claude-skills`, or `heydamir/unslop`, clones only the requested folder via Git Sparse Checkout, installs it into **both `.claude/skills/<skill>/` and `.agents/skills/<skill>/`**, and updates the 3D Voxel Studio catalog automatically.)*
3. **How Progressive Disclosure Works After Install:**
   - Read the installed skill's `SKILL.md` first, and load specific files from `references/` or run helper scripts in `scripts/` **only when needed**.

## 5. Constraints (`MUST DO` / `MUST NOT DO`)
- **MUST** use `bash .claude/hooks/install-skill.sh <skill-name>` so skills are synced to both `.claude/skills/` (Claude Code) and `.agents/skills/` (Antigravity IDE).
- **MUST** limit installation to 2–4 skills per project.
- **MUST NOT** read every file inside `references/` at once; load only the specific reference file matching the current task.
