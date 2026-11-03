# 🛡️ Agent Guard Template

**Template ตั้งต้นสำหรับใช้ AI เขียนโค้ด (รองรับทั้ง Claude Code และ Antigravity ใน VS Code)**

ช่วยให้ AI ทำงานตามสั่งอย่างตรงจุด **ไม่เดามั่ว ไม่วนลูปผลาญโควต้า ไม่เขียนโค้ดเวิ่นเว้อ** และสามารถ **สลับโปรแกรมทำต่อได้ทันทีเมื่อโควต้าฝั่งใดฝั่งหนึ่งหมดกลางคัน** โดยที่คุณไม่ต้องจำคำสั่งพิเศษใดๆ (พิมพ์สั่งงานด้วยภาษาพูดตามปกติได้เลย)

---

## 🤔 ทำไมต้องใช้ Template นี้? (เปรียบเทียบให้เห็นภาพ)

เวลาเราใช้ AI เขียนโค้ดในโปรเจกต์เปล่าๆ เรามักเจอปัญหาเหล่านี้:

| ปัญหาที่เจอประจำ (เมื่อไม่ใช้ Template) | สิ่งที่เกิดขึ้นเมื่อใช้ `agent-guard-template` |
| :--- | :--- |
| 💸 **เปลืองโควต้าฟรี:** สั่งแก้บั๊กนิดเดียว แต่ AI เดาแก้แล้วรันเทสต์พังวนไป 10 รอบจนโควต้าหมด | 🛑 **หยุดเมื่อตัน (2-Strike Limit):** ถ้า AI ลองแก้ 2 ครั้งแล้วยังไม่ผ่าน ระบบจะบังคับหยุด คืนค่าไฟล์เดิม แล้วสรุปทางเลือกมาถามคุณทันที |
| 🤯 **คิดเองเออเอง:** สั่งทำฟีเจอร์สั้นๆ AI ดันคิดสูตรธุรกิจเองมั่วๆ พอทำเสร็จต้องสั่งรื้อใหม่หมด | 🤝 **ถามก่อนมั่ว (`common-ground` & `0-Strike`):** ถ้าข้อมูลสำคัญขาดหาย AI จะสรุปสิ่งที่มันเข้าใจ 3–4 ข้อมาถามคุณสั้นๆ ก่อนลงมือเขียนโค้ด |
| 🐘 **โค้ดบวมเกินสั่ง:** สั่งแก้ปุ่มเดียว แต่ AI แถมเปลี่ยนชื่อตัวแปรและรื้อไฟล์ข้างเคียงมาให้เพียบ | ✂️ **แก้เฉพาะจุด (Surgical Edit):** แก้เฉพาะบรรทัดที่สั่ง ไม่แตะโค้ดส่วนอื่นที่ไม่ได้ขอ (จากการทดสอบจริงช่วยลดโค้ดส่วนเกินลง 40–65%) |
| 🔄 **รีวิวไม่รู้จบ:** พอสั่งให้ตรวจโค้ด ก็จับผิดเรื่องจุกจิก (เช่น ชื่อตัวแปร/ย่อหน้า) แก้ไปมาไม่จบสักที | ✅ **ตรวจเฉพาะจุดตาย (Blocker-Only):** ตรวจเฉพาะบั๊กที่ทำให้ระบบพังหรือรั่วไหล พอแก้เสร็จและเทสต์ผ่านจะอนุมัติ (`APPROVE`) จบงานใน 2 รอบ |
| 🔌 **โควต้าตัดกลางอากาศ:** กำลังทำค้างไว้ใน Claude Code แล้วโควต้าหมด ต้องมานั่งพิมพ์เล่าใหม่ใน VS Code | 🏃 **ส่งไม้ต่ออัตโนมัติ (Auto-Handoff):** บันทึกจุดที่แก้ค้างไว้ทุกครั้งอัตโนมัติ พอเปิดอีกโปรแกรมขึ้นมา แค่พิมพ์ว่า *"ทำต่อเลย"* ก็ลุยต่อได้ทันที |

---

## 🚀 วิธีติดตั้ง (ใช้เวลาไม่ถึง 2 นาที)

### วิธีที่ 1: เริ่มโปรเจกต์ใหม่
กดปุ่มสีเขียว **"Use this template"** ด้านบนของหน้า GitHub นี้ หรือรันคำสั่ง:
```bash
git clone https://github.com/bosocmputer/agent-guard-template.git my-project
cd my-project
chmod +x .claude/hooks/*.sh
```

### วิธีที่ 2: นำไปใส่ในโปรเจกต์เดิมที่มีอยู่แล้ว
ก๊อปปี้แค่ 4 ส่วนนี้ไปวางที่โฟลเดอร์นอกสุด (Root) ของโปรเจกต์คุณ:
1. ไฟล์ `AGENTS.md`
2. ไฟล์ `CLAUDE.md`
3. โฟลเดอร์ `.agents/`
4. โฟลเดอร์ `.claude/`

จากนั้นรันคำสั่งเปิดสิทธิ์สคริปต์ 1 ครั้ง:
```bash
chmod +x .claude/hooks/*.sh
```

---

## 🎯 วิธีเลือก Model ใน Claude Code (VS Code Extension / CLI) สำหรับมือใหม่

หลายคนโควต้าหมดไวเพราะเผลอเปิดโมเดลตัวแพงสุดทิ้งไว้ตลอดเวลา ใน **Claude Code** จะมีโมเดลหลักให้เลือกดังนี้ครับ:

| ชื่อ Model ใน Claude Code | เปรียบเทียบให้เข้าใจง่าย | กินโควต้าแค่ไหน? | ควรเลือกใช้ตอนไหน? |
| :--- | :--- | :---: | :--- |
| **🟢 `Sonnet` (ค่าเริ่มต้นที่แนะนำ)** | **ช่างฝีมืออาวุโส (Senior Dev)** เขียนโค้ดเก่ง ไว และทำตามกฎใน Template ได้ครบ | **ประหยัด คุ้มค่าที่สุด** | **ใช้เป็นตัวหลัก 85% ของเวลาทั้งหมด** (สร้างฟีเจอร์, แก้โค้ด, เขียนเทสต์, แก้บั๊กทั่วไป) |
| **🟣 `Opus`** | **สถาปนิกใหญ่ (Architect)** คิดวิเคราะห์ซับซ้อนเก่งมาก แต่ทำงานช้ากว่า | **กินโควต้าหนักมาก (หมดไวกว่าหลายเท่า)** | **ใช้เฉพาะ 15% ของงาน** ตอนคิดโครงสร้างระบบใหญ่ หรือตอนแก้บั๊กที่ `Sonnet` ลองแก้ครบ 2 ครั้งแล้วยังติด |
| **⚡ `Haiku`** | **ลูกมือวิ่งหาเอกสาร** เร็วมากแต่ไม่เหมาะกับงานคิดซับซ้อน | **ประหยัดสุดๆ (ถูกกว่า 10–20 เท่า)** | **ไม่ต้องกดเลือกเอง** เพราะ Template นี้ตั้งให้ตัวค้นหาไฟล์ (`explorer.md`) ใช้ `Haiku` อยู่เบื้องหลังให้อัตโนมัติแล้ว |

> **💡 ความลับที่ Template นี้ตั้งค่าช่วยคุณไว้แล้วใน `.claude/agents/`:**
> ปกติถ้าคุณเปิด **`Opus`** ไว้ในหน้าแชทหลัก แล้วสั่งงาน ระบบของ Claude Code จะใช้ `Opus` กับลูกมือทุกตัวจนโควต้าไหลเป็นน้ำ แต่ใน Template นี้ เราล็อกค่าในไฟล์ `.claude/agents/` ไว้ให้แล้วว่า:
> * ลูกมือค้นหาไฟล์ (`explorer.md`) ➔ บังคับใช้ **`haiku`** เสมอ
> * ลูกมือเขียนโค้ด/แก้บั๊ก/ตรวจโค้ด (`implementer.md`, `debugger.md`, `reviewer.md`) ➔ บังคับใช้ **`sonnet`** เสมอ
> *(หมายเหตุ: เราใช้ชื่อย่อ `sonnet` และ `haiku` ตามมาตรฐาน Official ของ Claude Code เพื่อให้ระบบดึงรุ่นล่าสุดให้อัตโนมัติโดยไม่ต้องคอยแก้เลขรุ่นในไฟล์)*

### วิธีเปลี่ยน Model ในหน้าแชทหลักของ Claude Code:
* **ใน VS Code Extension:** กดคลิกที่ชื่อโมเดลตรงแถบด้านล่างของช่องพิมพ์แชท แล้วเลือก `Sonnet` หรือ `Opus`
* **ในจอดำ (Terminal CLI):** พิมพ์ `/model sonnet` หรือ `/model opus` แล้วกด Enter

---

### 💡 ตัวอย่างสูตรใช้งานจริงให้โควต้าอยู่ได้นานที่สุด (Step-by-Step)

#### กรณีที่ 1: งานทั่วไปในชีวิตประจำวัน (ใช้ `Sonnet` ตัวเดียวจบ)
เมื่อต้องการเพิ่มปุ่ม แก้หน้าเว็บ สร้าง API หรือแก้บั๊กทั่วไป:
1. ตั้งโมเดลไว้ที่ **`Sonnet`**
2. พิมพ์สั่งงานตามปกติ เช่น:
   > *"เพิ่มช่องกรอกเบอร์โทรศัพท์ในหน้าสมัครสมาชิก และเช็กว่าต้องเป็นตัวเลข 10 หลัก"*
3. `Sonnet` จะแก้เฉพาะไฟล์ที่เกี่ยวข้องและรันเทสต์ตรวจให้จบในตัวโดยกินโควต้าน้อยมาก

#### กรณีที่ 2: งานยากหรือวางระบบใหญ่ (สูตร "คิดด้วย `Opus` ➔ เขียนโค้ดด้วย `Sonnet`")
เมื่อต้องทำระบบใหญ่หลายไฟล์ หรือเจอบั๊กยากที่ติดเบรกเกอร์ `2-Strike`:
1. **จังหวะที่ 1 (วางแผน):** สลับโมเดลไปที่ **`Opus`** แล้วพิมพ์ว่า:
   > *"/plan ออกแบบระบบตัดสต็อกสินค้าแบบจองคิวล่วงหน้าพร้อมป้องกันการกดซื้อพร้อมกัน"*
   *(ขั้นนี้ `Opus` จะใช้สมองระดับสูงสุดวางแผนออกมาสั้นๆ 10 บรรทัด โดยยังไม่เสียโควต้าเขียนโค้ดยาวๆ)*
2. **จังหวะที่ 2 (ลงมือเขียนโค้ด):** พอคุณอ่านแผนแล้วโอเค **ให้กดสลับโมเดลกลับมาเป็น `Sonnet` ทันที!** แล้วพิมพ์ว่า:
   > *"ตกลงตามแผนนี้ ลงมือเขียนโค้ดและรันเทสต์ได้เลย"*
   *(คุณจะได้โค้ดที่วางโครงสร้างโดย `Opus` แต่จ่ายค่าโควต้าตอนเขียนโค้ดในราคาประหยัดของ `Sonnet`!)*

---

## 💬 5 ตัวอย่างการใช้งานจริง (Use Cases)

คุณ**ไม่ต้องจำคำสั่งลัดใดๆ** แค่พิมพ์บอกความต้องการตามปกติ ระบบจะเลือกโหมดทำงานให้เองอัตโนมัติ:

---

### Use Case ที่ 1: เริ่มโปรเจกต์ใหม่ แล้วอยากให้ AI เก่งเฉพาะทางในภาษานั้นๆ
แทนที่จะยัดคู่มือทุกภาษาไว้ในโปรเจกต์จนเปลืองโควต้า คุณสามารถสั่งให้ AI ดึงเฉพาะคู่มือของภาษาที่ใช้จริงมาจากคลัง [`jeffallan/claude-skills`](https://github.com/jeffallan/claude-skills) ได้เลย

> 💬 **คุณพิมพ์แค่:**
> *"โปรเจกต์นี้ใช้ React, Tailwind และ NestJS ช่วยดึง skill ที่เกี่ยวข้องมาลงให้หน่อย"*

**สิ่งที่ระบบทำให้อัตโนมัติ:**
1. AI จะรันสคริปต์ `install-skill.sh` ไปดึงเฉพาะคู่มือ `react-expert`, `tailwind-expert`, และ `nestjs-expert` มาวางให้ทั้งใน `.claude/skills/` และ `.agents/skills/`
2. หลังจากนั้น เวลาคุณสั่งแก้หน้าเว็บ React หรือแก้ API ใน NestJS AI จะเปิดอ่านคู่มือของภาษานั้นเองโดยอัตโนมัติ

---

### Use Case ที่ 2: สั่งสร้างฟีเจอร์ใหม่ (ป้องกัน AI คิดเองเออเอง)
สมมติคุณสั่งสั้นๆ โดยยังไม่ได้บอกรายละเอียดทั้งหมด:

> 💬 **คุณพิมพ์แค่:**
> *"ช่วยสร้างระบบจองคิวร้านอาหาร พร้อมระบบเก็บเงินมัดจำและคืนเงินเวลากดยกเลิกให้หน่อย"*

**สิ่งที่ระบบทำให้อัตโนมัติ:**
* **ถ้าไม่มี Template:** AI จะมั่วตัวเลขขึ้นมาเอง เช่น คิดมัดจำคนละ 100 บาท และเขียนโค้ดยาวเหยียดเกือบ 200 บรรทัดซึ่งไม่ตรงกับที่ร้านคุณใช้จริง
* **เมื่อมี Template นี้:**
  1. AI จะเช็กก่อนว่าในโฟลเดอร์ `docs/llms/` มีไฟล์กฎของร้านวางไว้ไหม
  2. ถ้าจุดไหนยังไม่ชัดเจน AI จะสรุปสมมติฐานสั้นๆ 3–4 ข้อมาถามคุณก่อน เช่น:
     > *"ก่อนเริ่มเขียนโค้ด ขอเช็กความเข้าใจ 3 ข้อครับ: 1. เก็บมัดจำคงที่กี่บาทต่อคิว? 2. ต้องยกเลิกล่วงหน้ากี่ชั่วโมงถึงจะได้เงินคืน? 3. รอบนี้เก็บข้อมูลในหน่วยความจำก่อนใช่ไหมครับ?"*
  3. พอคุณตอบยืนยัน AI จึงเขียนโค้ดที่ตรงกับความต้องการของคุณในรอบเดียว ไม่ต้องรื้อแก้ใหม่

---

### Use Case ที่ 3: สั่งแก้บั๊กยากๆ (ป้องกัน AI เดาแก้จนโควต้าหมด)
สมมติเทสต์พัง หรือมีบั๊กที่ซับซ้อน:

> 💬 **คุณพิมพ์แค่:**
> *"หน้าคำนวณภาษีพัง ช่วยเช็กและแก้ให้หน่อย"*

**สิ่งที่ระบบทำให้อัตโนมัติ:**
1. AI จะอ่าน Error จริงและลองแก้ที่ต้นเหตุ (ครั้งที่ 1) แล้วรันเทสต์เฉพาะไฟล์นั้น
2. ถ้ายังไม่ผ่าน จะปรับสมมติฐานแล้วลองแก้ทับอีก 1 ครั้ง (ครั้งที่ 2)
3. **ถ้าครบ 2 ครั้งแล้วยังไม่ผ่าน (หรือติดที่ขาดสูตรคำนวณของบริษัท):**
   AI จะ**หยุดทันที** ย้อนโค้ดไฟล์นั้นกลับสู่สภาพเดิม แล้วรายงานว่าลองวิธีไหนไปแล้วบ้าง ติด Error อะไร และมีทางเลือกไหนให้คุณตัดสินใจต่อ (ไม่แอบรันเทสต์วนซ้ำ 10 รอบจนโควต้าเกลี้ยง)

---

### Use Case ที่ 4: โควต้า Claude Code หมดกลางคัน ➔ สลับมาทำต่อใน Antigravity (VS Code)
สมมติคุณกำลังให้ Claude Code เขียนระบบตะกร้าสินค้าอยู่ แล้วขึ้นแจ้งเตือน `Quota reached` กลางอากาศ:

> 💬 **คุณแค่สลับมาเปิด Antigravity ใน VS Code แล้วพิมพ์ว่า:**
> *"ทำส่วนที่ค้างไว้ต่อให้เสร็จเลย"*

**สิ่งที่ระบบทำให้อัตโนมัติ:**
1. ทุกครั้งที่ AI แก้ไฟล์ สคริปต์ `post-edit-format.sh` จะแอบจดบันทึกไว้ในไฟล์ `.agent-last-state.log` ว่าทำถึงไฟล์ไหนแล้ว
2. ทันทีที่คุณเปิดแชทใหม่ใน Antigravity สคริปต์ `auto-resume.sh` จะส่งข้อมูลงานค้างเข้าสมอง AI ตัวใหม่ตั้งแต่เริ่มแชท
3. Antigravity จะเช็ก `git diff` ดูโค้ดที่ Claude Code เขียนค้างไว้ รันเทสต์เช็กสถานะ แล้วเขียนต่อจากบรรทัดเดิมให้จบได้ทันที โดยที่คุณไม่ต้องนั่งพิมพ์อธิบายงานใหม่ตั้งแต่ต้น

---

### Use Case ที่ 5: สั่งตรวจโค้ดก่อนขึ้นระบบ (ไม่จับผิดจุกจิก)
เมื่อเขียนฟีเจอร์เสร็จแล้วอยากให้ AI ช่วยตรวจความเรียบร้อย:

> 💬 **คุณพิมพ์แค่:**
> *"ช่วยรีวิวโค้ดที่เพิ่งแก้ไปหน่อย"* (หรือพิมพ์ `/review` ใน Claude Code)

**สิ่งที่ระบบทำให้อัตโนมัติ:**
1. AI จะตรวจเฉพาะ **`[BLOCKER]`** เท่านั้น (เช่น บั๊กคำนวณผิด, ช่องโหว่ความปลอดภัย, ลืมเช็กสิทธิ์ผู้ใช้) โดย**ไม่บ่นเรื่องจุกจิก** เช่น ชื่อตัวแปรสั้นไป หรือการจัดย่อหน้า
2. เมื่อแก้ Blocker เสร็จและรันเทสต์ผ่านในรอบที่ 2 AI จะส่งคำตัดสิน `VERDICT: APPROVE` เพื่อจบงานทันที ไม่หาเรื่องรื้อโค้ดไปเรื่อยๆ

---

## 🛡️ ระบบป้องกันอัตโนมัติเบื้องหลัง (รองรับ JS/TS, Go, Flutter/Dart, Python, Rust ทันที)

Template นี้ตั้งค่าให้ตรวจจับภาษาของโปรเจกต์อัตโนมัติ (`package.json`, `go.mod`, `pubspec.yaml`, `pyproject.toml`, `Cargo.toml`) พร้อมสคริปต์ยามรักษาความปลอดภัยใน `.claude/hooks/`:
* **`validate-bash.sh`** — บล็อกคำสั่งอันตราย เช่น `rm -rf`, `git push --force`, `git restore` / `git checkout .` และบล็อกการแอบลงแพ็กเกจใหม่โดยไม่ถามคุณก่อน (`npm install`, `flutter pub add`, `go get`, `pip install`, `cargo add`)
* **`protect-sensitive-files.sh`** — บล็อกไม่ให้ AI แอบอ่านหรือแก้ไขไฟล์ความลับ (`.env`, `.pem`, `.key`, `.keystore`, `.jks`, `.p12`) หรือแก้ไฟล์ Lockfile โดยตรง (`package-lock.json`, `pubspec.lock`, `go.sum`, `poetry.lock`, `Cargo.lock`)
* **`post-edit-format.sh`** — จัด Format โค้ดอัตโนมัติตามภาษา (`prettier`, `gofmt`, `dart format`, `ruff format`, `rustfmt`) และบันทึกจุด Checkpoint ล่าสุดลง `.agent-last-state.log`
* **`loop-circuit-breaker.sh`** — นับจำนวนครั้งที่ AI รันคำสั่งเดิมซ้ำๆ หากรันเทสต์เดิมซ้ำเกิน 3 ครั้ง ระบบจะตัดเบรกเกอร์และสั่งให้ AI หยุดทันที

---

## 📂 โครงสร้างไฟล์ทั้งหมดใน Template นี้

```text
project-root/
├── AGENTS.md                                   # กฎหลัก + Auto-Router สำหรับ Antigravity / VS Code / Cursor
├── CLAUDE.md                                   # กฎหลัก + Auto-Router สำหรับ Claude Code
├── .mcp.json                                   # ตั้งค่า MCP (เริ่มต้นเป็นค่าว่างเพื่อประหยัดโควต้า)
├── .gitignore                                  # ป้องกันไฟล์ความลับและไฟล์สถานะชั่วคราวขึ้น Git
│
├── .agents/                                    # ⚡ ตั้งค่าอัตโนมัติสำหรับ Antigravity (VS Code)
│   ├── hooks.json                              # ผูก SessionStart, PreToolUse, PostToolUse
│   ├── rules/
│   │   ├── code-simplicity.md                  # Karpathy 4 Principles (Think, Simplicity, Surgical, Goal-Driven)
│   │   ├── execution-discipline.md             # Context Hygiene (trailofbits/claude-code-config) & Safe Rollback
│   │   └── testing-and-api.md                  # Real Testing (obra/superpowers TDD) & OWASP API Security
│   └── skills/
│       ├── auto-resume-handoff/SKILL.md        # 3-Phase Harness รับไม้ต่ออัตโนมัติ (Anthropic Long-Running Harness)
│       ├── common-ground/SKILL.md              # Socratic Discovery & YAGNI Scope (obra/superpowers brainstorming)
│       ├── db-migration/SKILL.md               # Zero-Downtime Migration (supabase/agent-skills + postgres-pro)
│       ├── pragmatic-review/SKILL.md           # Blocker-Only Review ไม่เกิน 2 รอบ (obra/superpowers review)
│       ├── root-cause-debug/SKILL.md           # 4-Phase Debugging (obra/superpowers) + 0/2-Strike Breaker
│       ├── tech-stack-skills/SKILL.md          # ดึง Skill เฉพาะทางจาก jeffallan/claude-skills อัตโนมัติ
│       └── verification-before-completion/     # Iron Law & 5-Step Gate Function (Test + Build + Smoke Check)
│
└── .claude/                                    # 🤖 ตั้งค่าอัตโนมัติสำหรับ Claude Code
    ├── settings.json                           # สิทธิ์คำสั่งปลอดภัย + ผูกสคริปต์ Hooks ($CLAUDE_PROJECT_DIR)
    ├── agents/                                 # 4 Sub-Agents (พร้อม model, maxTurns, disallowedTools & skills preload)
    │   ├── explorer.md                         # สำรวจโค้ดแบบ Read-only (haiku, maxTurns: 6)
    │   ├── implementer.md                      # แก้โค้ดแบบ Surgical Edit (sonnet, maxTurns: 15 + skills preload)
    │   ├── debugger.md                         # วิเคราะห์ต้นตอและตัดลูป 2-Strike (sonnet, maxTurns: 10 + skills preload)
    │   └── reviewer.md                         # ตรวจเฉพาะ Blocker แบบ Read-only (sonnet, maxTurns: 8 + skills preload)
    ├── rules/                                  # กฎโหลดตาม Path ไฟล์ (ชุดเดียวกับ .agents/rules)
    ├── skills/                                 # ทักษะอัตโนมัติ (ชุดเดียวกับ .agents/skills)
    ├── commands/                               # คำสั่งลัด (/plan, /common-ground, /fix, /review, /verify, /handoff)
    └── hooks/                                  # 🛡️ สคริปต์ยามรักษาความปลอดภัย Dual-Mode (Claude + Antigravity)
        ├── auto-resume.sh                      # ฉีดสถานะงานค้างเข้าแชทใหม่อัตโนมัติ (SessionStart)
        ├── validate-bash.sh                    # บล็อก rm -rf, git restore/checkout ทับโค้ด, และการลง pkg มั่ว
        ├── protect-sensitive-files.sh          # บล็อกการแก้ไขไฟล์ .env, .pem, .key, และ lockfiles
        ├── loop-circuit-breaker.sh             # บล็อกเมื่อ AI รันคำสั่งเทสต์/บิลด์เดิมซ้ำเกิน 3 ครั้ง
        ├── post-edit-format.sh                 # จัด Format อัตโนมัติ + บันทึกจุด Checkpoint ล่าสุด
        └── install-skill.sh                    # ดึง Skill เฉพาะทางจาก jeffallan/claude-skills แบบ Sparse Checkout
```

---

## 📚 มาตรฐานและงานวิจัยที่นำมาพัฒนา (Built On)

* **Anthropic Claude Code Official Specification & Engineering:** ใช้การจำกัด `model`, `maxTurns`, `disallowedTools`, และการ Preload `skills` ในระดับ Sub-agent Frontmatter ร่วมกับ `$CLAUDE_PROJECT_DIR` Hooks และรูปแบบ *Effective Harnesses for Long-Running Agents*
* **Antigravity Customization System (`.agents/`):** รองรับ Progressive Disclosure ของ Rules/Skills และ JSON Lifecycle Hooks (`hooks.json`)
* **[`forrestchang/andrej-karpathy-skills`](https://github.com/forrestchang/andrej-karpathy-skills):** กฎ 4 ข้อของ Karpathy (*Think Before Coding*, *Simplicity First*, *Surgical Changes*, *Goal-Driven Execution*)
* **[`obra/superpowers`](https://github.com/obra/superpowers):** โปรโตคอล *Verification Before Completion*, *4-Phase Systematic Debugging*, *Socratic Brainstorming*, *Code Review Convergence*, และ *Real-Code TDD*
* **[`trailofbits/claude-code-config`](https://github.com/trailofbits/claude-code-config):** สถาปัตยกรรม *Two-Layer Context Hygiene* และการแยกขอบเขตการส่งงานเข้า Sub-agent เพื่อรักษาขนาด Context Window
* **[`supabase/agent-skills`](https://github.com/supabase/agent-skills) & [`jeffallan/claude-skills`](https://github.com/jeffallan/claude-skills):** กฎ *Zero-Downtime Postgres Migration / RLS* และระบบดึงทักษะเฉพาะทางตาม Tech Stack จริงแบบ Sparse Checkout (`install-skill.sh`)
