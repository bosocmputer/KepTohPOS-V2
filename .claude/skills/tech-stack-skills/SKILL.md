---
name: tech-stack-skills
description: Use when initializing a project, declaring the project tech stack, or installing framework-specific skills from jeffallan/claude-skills (ใช้เมื่อเริ่มโปรเจกต์ใหม่หรือต้องการดึง Skill เฉพาะทางของภาษามาติดตั้ง)
---
# On-Demand Tech Stack Skill Installer (`jeffallan/claude-skills` Progressive Disclosure)

> **Reference Architecture:** [`jeffallan/claude-skills`](https://github.com/jeffallan/claude-skills) (67 Specialized Skills with Progressive `SKILL.md` + `references/` Routing)

## 1. The Iron Law
> **PROGRESSIVE DISCLOSURE — CHERRY-PICK 2–4 STACK SKILLS MAX, NEVER BULK-INSTALL ALL 67.**

Every installed skill's `name` and `description` are loaded into the agent's system prompt at startup. Installing all 67 skills wastes context window tokens every turn. Install **only the 2–4 skills that match the active repository's tech stack**.

## 2. Official `jeffallan/claude-skills` Catalog (Verified Folder Names)

| Project Layer | Verified Skill Names in `jeffallan/claude-skills` |
| :--- | :--- |
| **Frontend & Mobile** | `react-expert`, `nextjs-developer`, `vue-expert`, `angular-architect`, `tailwind-expert`, `react-native-expert`, `flutter-expert` |
| **Backend Frameworks** | `nestjs-expert`, `fastapi-expert`, `django-expert`, `laravel-specialist`, `spring-boot-engineer`, `rails-expert`, `dotnet-core-expert` |
| **Core Languages** | `typescript-pro`, `python-pro`, `golang-pro`, `rust-engineer`, `java-architect`, `cpp-pro`, `csharp-developer` |
| **Database & API** | `postgres-pro`, `sql-pro`, `database-architect`, `graphql-architect`, `api-designer`, `microservices-architect` |
| **Testing & Quality** | `playwright-expert`, `test-master`, `fullstack-guardian`, `code-reviewer`, `debugging-wizard` |
| **Security & DevOps** | `security-reviewer`, `secure-code-guardian`, `devops-engineer`, `kubernetes-specialist`, `terraform-engineer`, `cloud-architect` |

## 3. Core Workflow (Dual-Agent Sparse Installation)

1. **Detect Stack:** Check `package.json`, `pyproject.toml`, `go.mod`, or `Cargo.toml` (or read the user's prompt) to identify the 2–4 relevant skills.
2. **Execute Sparse Installer:** Run the built-in sparse-checkout installer script:
   ```bash
   bash .claude/hooks/install-skill.sh <skill-1> <skill-2>
   ```
3. **How Progressive Disclosure Works After Install:**
   - The script clones only the requested skill folder(s) (including `SKILL.md` and `references/*.md`) into both `.claude/skills/<skill>/` and `.agents/skills/<skill>/`.
   - When coding in that framework, read the skill's `SKILL.md` first, and load specific files from `references/` **only when needed** per the skill's `Reference Routing Guide`.

## 4. Constraints (`MUST DO` / `MUST NOT DO`)
- **MUST** use `bash .claude/hooks/install-skill.sh <skill-name>` so skills are synced to both `.claude/skills/` and `.agents/skills/`.
- **MUST** limit installation to 2–4 skills per project.
- **MUST NOT** read every file inside `references/` at once; load only the specific reference file matching the current task.
