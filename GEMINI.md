# Project Overview & Universal Agent Governance
> ใช้ร่วมกันทั้ง **Claude Code** (`.claude/`) และ **Antigravity / VS Code** (`.agents/`)
> **Upstream Architectures:** [`anthropics/skills`](https://github.com/anthropics/skills) • [Anthropic AI-Native SDLC Playbook](https://claude.com/resources/articles/the-ai-native-sdlc-playbook) • [`cloudflare/security-audit-skill`](https://github.com/cloudflare/security-audit-skill) • [`andrej-karpathy-skills`](https://github.com/forrestchang/andrej-karpathy-skills) • [`obra/superpowers`](https://github.com/obra/superpowers) • [`garrytan/gstack`](https://github.com/garrytan/gstack) • [`jeffallan/claude-skills`](https://github.com/jeffallan/claude-skills) • [`supabase/agent-skills`](https://github.com/supabase/agent-skills) • [`trailofbits/claude-code-config`](https://github.com/trailofbits/claude-code-config) • [`heydamir/unslop`](https://github.com/heydamir/unslop) • [`mrdoob/three.js`](https://github.com/mrdoob/three.js)

## 0. Auto-Detect Tech Stack & Quick Commands (รองรับหลายภาษาอัตโนมัติ)
ให้ตรวจสอบไฟล์ตั้งต้นในโปรเจกต์เพื่อเลือกใช้คำสั่งรันเทสต์และตรวจโค้ดให้ตรงกับภาษาที่ใช้จริงโดยอัตโนมัติ:

| ภาษา / Framework (ตรวจจากไฟล์ในโปรเจกต์) | คำสั่งรันเทสต์เฉพาะไฟล์ (Tier 1: Single-File Test) | คำสั่งตรวจ Type / Analyze / Build (Tier 2) |
| :--- | :--- | :--- |
| **Node.js / TypeScript** (`package.json`) | `node --test <path>` หรือ `npm test -- <path>` | `npx tsc --noEmit` \| `npm run build` |
| **Go (Golang)** (`go.mod`) | `go test -v ./path/to/pkg -run <TestName>` | `go vet ./...` \| `go build ./...` |
| **Flutter / Dart** (`pubspec.yaml`) | `flutter test test/<file>_test.dart` | `flutter analyze` |
| **Python** (`pyproject.toml` / `requirements.txt`) | `pytest <path/to/test_file.py>` | `ruff check .` \| `mypy .` |
| **Rust** (`Cargo.toml`) | `cargo test <test_name>` | `cargo check` \| `cargo clippy` |

- **Dev Server / App Runner:** ห้ามรันเซิร์ฟเวอร์ค้างใน Foreground ของ Agent (เช่น `npm run dev`, `go run`, `flutter run`) ให้ตรวจพอร์ตด้วย `lsof -i :<port>` แทน
- **Local Framework Docs (`llms.txt`):** หากมีเอกสารย่อใน `docs/llms/` หรือ `llms.txt` ให้อ่านจากที่นั่นก่อนเสมอแทนการเปิด MCP Server หนักๆ

---

## 1. Zero-Command Auto-Routing & Explicit Subagent Delegation (บังคับแยกโมเดล Haiku / Sonnet อัตโนมัติ)
> **EXPLICIT USER AUTHORIZATION (OVERRIDES DEFAULT `Agent` TOOL HESITATION):**
> ผู้ใช้สั่งอนุญาตและกำหนดเป็นข้อบังคับของโปรเจกต์นี้ (Explicit User Instruction overriding `"Do not spawn agents unless the user asks"`) ให้เอเจนต์หลักทำหน้าที่เป็น **Orchestrator** และ **ต้องเรียกใช้เครื่องมือ `Agent` (`explorer`, `implementer`, `debugger`, `reviewer`) พร้อมระบุ `model` ตามตารางด้านล่างทันที** เมื่อเจอก้อนงานหลายขั้นตอน เพื่อป้องกันการผลาญโควต้า `Opus` ในหน้าต่างหลัก:

| สิ่งที่ผู้ใช้พิมพ์สั่ง / ลักษณะงาน | ขนาดก้อนงาน | การเลือกใช้ Sub-Agent (`Agent` Tool) และ `model` ที่บังคับใช้ทันที |
| :--- | :--- | :--- |
| **"โปรเจกต์นี้ใช้ React / NestJS / สร้าง PDF / MCP..."** | ตั้งค่าเริ่มต้น / ดึง Skill เสริม | โหลด `tech-stack-skills` ดึงเฉพาะ 2–4 Skills ที่ใช้จาก `anthropics/skills`, `jeffallan/claude-skills`, หรือ `heydamir/unslop` ผ่าน `install-skill.sh` |
| **"ทำต่อจากที่ค้างไว้ / โควต้าอีกฝั่งหมด"** | สลับ Agent กลางคัน | โหลด `auto-resume-handoff` อ่าน `.agent-last-state.log` + `git diff` แล้วทำต่อทันทีไม่ต้องถามซ้ำ |
| **"สร้างระบบ... / เพิ่มฟีเจอร์..." (โจทย์กว้าง)** | มีจุดกำกวม / เลือกทำได้หลายแบบ | โหลด `common-ground` สรุปสมมติฐาน 3–4 ข้อสั้นๆ ให้ผู้ใช้ยืนยันก่อนเริ่มเขียนโค้ด |
| **งานจิ๋วชัดเจน (อ่าน/แก้ 1–2 ไฟล์ที่รู้ตำแหน่งแล้ว)** | **Trivial Task (1–2 ไฟล์)** | ทำเองในหน้าต่างหลักแบบ Surgical Edit + รันเทสต์เฉพาะไฟล์ (ห้ามแตก Sub-agent สำหรับคำสั่งสั้นๆ 1–2 ครั้ง) |
| **สำรวจหาพิกัดโค้ด / ไล่โครงสร้างที่ยังไม่รู้ไฟล์ (>3 ไฟล์)** | **Multi-File Exploration** | **Claude:** `Agent(subagent_type="explorer", model="haiku")` • **Antigravity:** `invoke_subagent(TypeName="research", Model="flash", Role="Codebase Explorer")` |
| **ลงมือเขียน/แก้โค้ดหลายไฟล์ (2–5 ไฟล์) + รันเทสต์ย่อยจนผ่าน** | **Multi-Step Implementation** | **Claude:** `Agent(subagent_type="implementer", model="sonnet")` • **Antigravity:** `invoke_subagent(TypeName="self", Model="inherit", Role="Surgical Implementer")` |
| **"เทสต์พัง / บั๊กหน้า... / Error..." (ต้องสืบหาสาเหตุและลองแก้)** | **Root-Cause Debugging** | **Claude:** `Agent(subagent_type="debugger", model="sonnet")` • **Antigravity:** `invoke_subagent(TypeName="self", Model="inherit", Role="2-Strike Debugger")` |
| **"ช่วยตรวจโค้ด / รีวิว / รันชุดทดสอบ E2E หรือ Browser"** | **QA Review & E2E Suite** | **Claude:** `Agent(subagent_type="reviewer", model="sonnet")` • **Antigravity:** `invoke_subagent(TypeName="browser" หรือ "self", Model="inherit", Role="QA Verifier")` |
| **"ตรวจความปลอดภัย / `/security-audit` / เช็ก RLS & RPC"** | **Security Audit (Cloudflare Gate)** | โหลด `security-audit` ส่ง `explorer` (`haiku`/`flash`) หาพื้นผิวโจมตี + `reviewer` (`sonnet`) ไล่เส้นทาง `entrypoint ➔ sink` แยก `[CONFIRMED]` ออกจาก `[NEEDS_VALIDATION]` |
| **"สร้าง 3D Viewer / Three.js / WebGL"** | งานแสดงผล 3 มิติบนเว็บ | โหลด `threejs-expert` (มาตรฐาน `mrdoob/three.js r187+`: `three/addons/*`, `HDRLoader`, `OutputPass`, `dispose()`) |
| **"เปิดจอ 3D / เปิดมอนิเตอร์ 3D / เช็กหลักฐานโมเดล"** | เปิดศูนย์บัญชาการ 3D / ตรวจสถิติ | รัน `bash .claude/hooks/open-hud.sh` (จอ 3D) หรือ `bash .claude/hooks/audit-session-proof.sh` (ตรวจสัดส่วนโมเดลจาก `.jsonl`) |

---

## 2. Anti-Loop & Quota Protection Guardrails (กฎเหล็กกันผลาญโควต้า)
1. **0-Strike for Missing Business Spec:**
   - หากรากของงานขาดสูตรคำนวณทางธุรกิจ อัตราส่วนลด หรือค่าคงที่เฉพาะขององค์กรที่ไม่ได้ระบุในโค้ดหรือ `docs/llms/` **ห้ามเดาสุ่มตัวเลขและห้ามเขียนโค้ดเผื่ออนาคตเด็ดขาด** ให้ส่ง `CIRCUIT_BREAKER: MISSING_SPEC` ถามผู้ใช้ทันที
2. **2-Strike Technical Bug Limit:**
   - เมื่อแก้บั๊กทางเทคนิค หากลองแก้และรันเทสต์แล้วยังพังซ้ำครบ **2 ครั้ง** ให้ **หยุดทันที (STOP)**
   - ใช้เครื่องมือ `Edit` คืนค่าโค้ดกลับสู่สภาพเดิม แล้วส่ง `CIRCUIT_BREAKER: 2_STRIKES_REACHED` สรุปสิ่งที่ลองไปแล้ว 2 ครั้ง พร้อมทางเลือกให้ผู้ใช้ตัดสินใจ
3. **Targeted Exploration Only:**
   - ใช้ `Grep` หรือ `Glob` เจาะจงโฟลเดอร์ที่เกี่ยวข้อง ห้ามกวาดอ่านไฟล์ทั้งโปรเจกต์โดยไม่จำเป็น
   - ก่อนสร้างไฟล์ใหม่ ให้อ่านไฟล์ประเภทเดียวกันในโปรเจกต์ 1 ไฟล์เพื่อเลียนแบบโครงสร้าง การตั้งชื่อ และเวอร์ชันของ Library เดิม
4. **Execution Ceiling:**
   - ห้ามแก้ไขเกิน 5 ไฟล์ใน 1 รอบคำสั่งโดยไม่แจ้งให้ผู้ใช้ทราบก่อน

---

## 3. Integrity, Git Safety & Security Rules
1. **Gate Integrity & Anti-Reward-Hacking (`garrytan/gstack RH-1..RH-16 & PL-2`):**
   - ห้ามแก้ไขค่าคาดหวัง (`expect`/`assert`), ลบเทสต์, ใส่ `.skip` / `.only` (`RH-1`), หรือผ่อนปรนตัวเลขเกณฑ์/เวลา Timeout (`RH-15`) เพื่อให้เทสต์ผ่านแบบผิดๆ
   - ห้ามเขียนดัก `if (process.env.NODE_ENV === 'test')` หรือ `if (process.env.CI)` ในโค้ดทำงานจริงเพื่อลัดวงจรผลเทสต์ (`RH-12`)
   - ห้ามใส่ `@ts-ignore`, `@ts-expect-error`, `eslint-disable`, `# type: ignore`, หรือ `// nolint` เพื่อซ่อนปัญหา (`RH-13`)
   - **Zero-Run Green (`PL-2`):** หากรันเทสต์ได้ `Exit Code 0` แต่รันไป `0 ข้อ (0 tests ran)` ถือว่าเทสต์ล้มเหลว ต้องแก้พาธ/ตัวกรองและรันใหม่จนมีเทสต์รันจริง (`tests_ran >= 1`)
2. **Git, Dependency & Production Release Gate (`Anthropic AI-Native SDLC Stage 5`):**
   - ห้ามรัน `git checkout .`, `git restore`, `git reset --hard`, `git clean -f`, หรือ `git push --force` / `+main` เพราะจะทำลายโค้ดที่ผู้ใช้เขียนค้างไว้แต่ยังไม่ได้ Commit
   - ห้ามรันคำสั่งติดตั้งแพ็กเกจใหม่ (`npm install`, `pnpm add`, `flutter pub add`, `go get`, `pip install`, `cargo add`) โดยไม่ถามผู้ใช้ก่อน (เมื่อผู้ใช้อนุญาตในแชทแล้ว ให้รันโดยใส่ `DEPS_APPROVED=1` นำหน้าคำสั่ง เช่น `DEPS_APPROVED=1 flutter pub add <pkg>`)
   - **Production Deploy & Live DB Migration Gate:** ห้ามรันคำสั่งปล่อยของขึ้น Production (`vercel --prod`, `firebase deploy`, `wrangler deploy`, `fly deploy`) หรือยิง Migration เข้าฐานข้อมูลจริง (`prisma migrate deploy`, `supabase db push`, `terraform apply`, `kubectl apply`) โดยไม่ได้รับอนุญาตจากผู้ใช้ก่อน (เมื่อผู้ใช้อนุญาตในแชทแล้ว ให้ใส่ `RELEASE_APPROVED=1` นำหน้าคำสั่ง)
   - **Anti-Test-Tampering (`Stage 4`):** ในระหว่างซ่อมบั๊ก (`debugger` / `strikeCount >= 1`) ห้ามแก้ไขไฟล์เทสต์ที่มีอยู่เดิมเพื่อให้เทสต์ผ่านหลอกๆ (`protect-sensitive-files.sh` จะบล็อกด้วย `exit 2`)
3. **Secrets & Database Protection:**
   - ห้ามอ่าน แก้ไข แสดงผล หรือ Commit ไฟล์ `.env*`, `*.key`, `*.pem`, `*.keystore`, `*.jks`, `*.p12`, `*.sqlite`, `*.db` เด็ดขาด (ดูโครงสร้างตัวแปรจาก `.env.example` แทน)

---

## 4. Evidence-Based Reporting (No Over-Claiming)
- รายงานเฉพาะสิ่งที่รันตรวจสอบจริงในเทิร์นนี้ พร้อมระบุ **`คำสั่งที่รัน`** และ **`ผลลัพธ์จริงจาก Terminal`**
- สิ่งที่ยังไม่ได้รันทดสอบ (เช่น ไม่มี Server หรือยังไม่ได้รัน E2E) ให้ระบุตรงๆ ว่า **"ยังไม่ได้รันทดสอบ"**
- ห้ามใช้คำพูดเคลมเกินจริง เช่น `"เสร็จสมบูรณ์ 100%"`, `"สมบูรณ์แบบ"`, `"ไม่มีบั๊กแน่นอน"`

---

## 5. Known Project Pitfalls (`Anthropic SDLC Playbook Stage 3 — 2-Repeat Memory`)
> กฎเหล็ก: เมื่อ AI ทำผิดพลาดเรื่องเดิมในโปรเจกต์นี้ซ้ำเป็นครั้งที่ 2 ให้สรุปบทเรียนสั้นๆ 1 บรรทัดเพิ่มไว้ด้านล่างนี้เสมอ (ทั้งใน `CLAUDE.md` และ `AGENTS.md`) เพื่อป้องกันการทำผิดซ้ำในแชทถัดไป
- ห้ามแก้ไฟล์เทสต์เดิมเพื่อลดความเข้มงวดของ `expect`/`assert` เวลาซ่อมบั๊ก ให้แก้ที่โค้ดต้นเหตุเท่านั้น
- เมื่อแก้ไขกฎหรือทักษะใน `.claude/` ต้องซิงค์ให้ตรงกับ `.agents/` เสมอเพื่อรองรับการสลับค่ายระหว่าง Claude Code และ Antigravity IDE
