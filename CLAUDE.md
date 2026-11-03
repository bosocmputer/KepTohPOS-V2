# Project Overview & Universal Agent Governance
> ใช้ร่วมกันทั้ง **Claude Code** (`.claude/`) และ **Antigravity / VS Code** (`.agents/`)
> **Upstream Architectures:** [`andrej-karpathy-skills`](https://github.com/forrestchang/andrej-karpathy-skills) • [`obra/superpowers`](https://github.com/obra/superpowers) • [`jeffallan/claude-skills`](https://github.com/jeffallan/claude-skills) • [`supabase/agent-skills`](https://github.com/supabase/agent-skills) • [`trailofbits/claude-code-config`](https://github.com/trailofbits/claude-code-config)

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

## 1. Zero-Command Auto-Routing (พิมพ์ความต้องการอย่างเดียว ระบบเลือกโหมดเอง)
วิเคราะห์เจตนาจากประโยคของผู้ใช้และเลือกโหลดโปรโตคอลหรือ Sub-agent อัตโนมัติโดยไม่ต้องรอคำสั่ง `/slash`:

| สิ่งที่ผู้ใช้พิมพ์สั่ง | ขนาด/ลักษณะงาน | โปรโตคอล / Sub-Agent ที่ต้องใช้ทันที |
| :--- | :--- | :--- |
| **"โปรเจกต์นี้ใช้ React / NestJS..."** | ตั้งค่าเริ่มต้น / แจ้ง Tech Stack | โหลด `tech-stack-skills` ดึงเฉพาะ 2–4 Skills ที่ใช้จาก `jeffallan/claude-skills` ผ่าน `install-skill.sh` |
| **"ทำต่อจากที่ค้างไว้ / โควต้าอีกฝั่งหมด"** | สลับ Agent กลางคัน | โหลด `auto-resume-handoff` อ่าน `.agent-last-state.log` + `git diff` แล้วทำต่อทันทีไม่ต้องถามซ้ำ |
| **"สร้างระบบ... / เพิ่มฟีเจอร์..." (โจทย์กว้าง)** | มีจุดกำกวม / เลือกทำได้หลายแบบ | โหลด `common-ground` สรุปสมมติฐาน 3–4 ข้อสั้นๆ ให้ผู้ใช้ยืนยันก่อนเริ่มเขียนโค้ด |
| **"แก้ปุ่ม / แก้ฟังก์ชัน..." (1–2 ไฟล์ชัดเจน)** | **Trivial Task** | ลงมือแก้แบบ Surgical Edit + รันตรวจด้วย `verification-before-completion` ทันที (ห้ามเรียก Sub-agent) |
| **"ปรับโครงสร้าง / เชื่อมต่อหลายโมดูล" (>3 ไฟล์)** | **Complex Task** | เรียก `explorer` sub-agent สำรวจไฟล์ที่เกี่ยวข้อง แล้วสรุปแผนไม่เกิน 10 บรรทัดรอผู้ใช้ยืนยัน |
| **"เทสต์พัง / บั๊กหน้า... / Error..."** | แก้บั๊ก / วิเคราะห์ปัญหา | เรียก `debugger` sub-agent (ใช้กฎ `0-Strike Missing Spec` และ `2-Strike Bug Limit`) |
| **"ช่วยตรวจโค้ด / รีวิวให้หน่อย"** | ตรวจสอบคุณภาพและความปลอดภัย | เรียก `reviewer` sub-agent (ตรวจเฉพาะ `[BLOCKER]` ห้ามติจุกจิก จบภายในไม่เกิน 2 รอบ) |

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
1. **Test & Linter Integrity (ห้ามโกงผลเทสต์):**
   - ห้ามแก้ไขค่าคาดหวัง (`expect`/`assert`), ลบเทสต์, หรือใส่ `.skip` / `.only` ในไฟล์เทสต์เดิมเพื่อให้เทสต์ผ่านแบบผิดๆ
   - ห้ามใส่ `@ts-ignore`, `@ts-expect-error`, หรือ `eslint-disable` เพื่อซ่อนปัญหาโดยไม่ได้รับอนุญาตจากผู้ใช้
2. **Git & Dependency Safety:**
   - ห้ามรัน `git checkout .`, `git restore`, `git reset --hard`, `git clean -f`, หรือ `git push --force` เพราะจะทำลายโค้ดที่ผู้ใช้เขียนค้างไว้แต่ยังไม่ได้ Commit
   - ห้ามรัน `npm install`, `pnpm add`, หรือ `yarn add` เพิ่มแพ็กเกจใหม่โดยไม่ถามผู้ใช้ก่อน
3. **Secrets & Database Protection:**
   - ห้ามอ่าน แก้ไข แสดงผล หรือ Commit ไฟล์ `.env*`, `*.key`, `*.pem`, `*.sqlite`, `*.db` เด็ดขาด (ดูโครงสร้างตัวแปรจาก `.env.example` แทน)

---

## 4. Evidence-Based Reporting (No Over-Claiming)
- รายงานเฉพาะสิ่งที่รันตรวจสอบจริงในเทิร์นนี้ พร้อมระบุ **`คำสั่งที่รัน`** และ **`ผลลัพธ์จริงจาก Terminal`**
- สิ่งที่ยังไม่ได้รันทดสอบ (เช่น ไม่มี Server หรือยังไม่ได้รัน E2E) ให้ระบุตรงๆ ว่า **"ยังไม่ได้รันทดสอบ"**
- ห้ามใช้คำพูดเคลมเกินจริง เช่น `"เสร็จสมบูรณ์ 100%"`, `"สมบูรณ์แบบ"`, `"ไม่มีบั๊กแน่นอน"`
