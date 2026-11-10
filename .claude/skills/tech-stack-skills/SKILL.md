---
name: tech-stack-skills
description: Use ONLY when the task requires specialized document/tooling workflows (pdf, docx, xlsx, pptx, mcp-builder, webapp-testing) or when the user explicitly requests installing an external skill via install-skill.sh (ใช้เฉพาะเมื่อต้องการติดตั้งเครื่องมือจัดการเอกสาร PDF/Office, MCP, หรือเมื่อผู้ใช้สั่งติดตั้ง Skill เองเท่านั้น)
---
# On-Demand Tooling & Capability Skill Installer (`anthropics/skills`)

## 1. The Iron Law (`SkillsBench` & *The Bitter Lesson* Principle)
> **DO NOT AUTO-INSTALL GENERIC LANGUAGE OR FRAMEWORK TUTORIAL SKILLS.**

1. **Why:** Frontier models already encode standard language and framework syntax (React, Next.js, Flutter, Python, Go, SQL) in their pre-trained weights. Loading generic syntax skills wastes context tokens and introduces instruction drift. Always learn project-specific conventions by reading 1–2 existing files in the repository and `.claude/rules/project-pitfalls.md`.
2. **When to Use `install-skill.sh`:** Install external skills **only** when the task requires:
   - **Production Document Workflows (`anthropics/skills`):** `pdf`, `docx`, `xlsx`, `pptx`
   - **Specialized Agent / QA Harnesses (`anthropics/skills`):** `mcp-builder`, `webapp-testing`, `frontend-design`, `web-artifacts-builder`, `claude-api`
   - **Explicit User Request:** The user specifically asks to install a named skill from `anthropics/skills`, `jeffallan/claude-skills`, or `heydamir/unslop`.

## 2. Verified Capability Catalog (`anthropics/skills`)

| Category | Verified Skill Names (`github.com/anthropics/skills`) |
| :--- | :--- |
| **Production Document Suite** | `pdf` *(pypdf/pdfplumber/reportlab/OCR/forms)*, `docx` *(docx-js + XML redlines)*, `xlsx` *(openpyxl + LibreOffice `recalc.py`)*, `pptx` *(pptxgenjs + visual QA)* |
| **QA, MCP & Agent Tooling** | `webapp-testing` *(Playwright + `with_server.py`)*, `mcp-builder` *(MCP TypeScript SDK v2 & FastMCP)*, `claude-api` *(Claude SDKs)*, `skill-creator` |
| **UI & Web Artifacts** | `frontend-design` *(Studio-grade UI)*, `web-artifacts-builder`, `theme-factory`, `canvas-design`, `unslop` *(from `heydamir/unslop`)* |

*(Note: `install-skill.sh` also supports `jeffallan/claude-skills` if explicitly requested by the user, but never auto-install them by default.)*

## 3. Execution Command (Dual-Engine Sparse Checkout)

```bash
bash .claude/hooks/install-skill.sh <skill-1> [skill-2]
```
- Clones only the requested skill folder via Git Sparse Checkout into `.claude/skills/<skill>/` (shared automatically with Antigravity via `.agents/skills.json`).
- Limit installation to **1–3 capability skills maximum** per project, and read files inside `references/` only when needed.
