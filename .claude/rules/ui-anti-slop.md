---
paths:
  - "**/*.{tsx,jsx,vue,svelte,html,css,scss}"
  - "lib/**/*.dart"
  - "src/**/components/**"
  - "src/**/pages/**"
  - "src/**/app/**"
---
# UI Anti-Slop & Production Design Standards (`heydamir/unslop` + `anthropics/skills/frontend-design`)

> **Reference Architecture:** [`heydamir/unslop`](https://github.com/heydamir/unslop) & [`anthropics/skills`](https://github.com/anthropics/skills) (`skills/frontend-design/SKILL.md` — Anti-Default Tells & 2-Pass Critique)
> **Activation:** โหลดอัตโนมัติเฉพาะเมื่อสร้างหรือแก้ไขไฟล์ Frontend Web (`React`, `Next.js`, `Vue`) หรือ Mobile (`Flutter / Dart`) เท่านั้น (ไม่กินโควต้างาน Backend)

## 1. The Iron Law of UI Implementation
> **NO GENERIC "AI SLOP" UI — APPLY ALL DESIGN DIMENSIONS & ELIMINATE THE 5 AI DESIGN TELLS IN A SINGLE PASS.**

ห้ามเขียน UI แบบบล็อกสำเร็จรูปของ AI แล้วค่อยมาวนแก้ทีหลัง ให้บังคับใช้มาตรฐานทั้ง 11 ด้านตั้งแต่การเขียนโค้ดรอบแรก:

### 1. Icons (ห้ามวาด `<svg>` เอง และห้ามใช้ Emoji แทนไอคอน)
- **ห้ามเด็ดขาด:** ห้ามเขียนแท็ก `<svg><path d="..."/></svg>` เองด้วยมือ และห้ามนำ Emoji (เช่น 🚀, ✨, 📊, 🔒) มาวางเป็นไอคอนหน้าปุ่ม เมนู หรือหัวข้อเด็ดขาด
- **ไลบรารีมาตรฐานที่ต้องใช้:**
  - **Web (React / Next.js / Vue):** ใช้ `lucide-react` (`lucide-icons`) สำหรับไอคอนระบบ และใช้ `simple-icons` สำหรับโลโก้แบรนด์
  - **Flutter / Dart:** ใช้ `lucide_icons` หรือ `Icons.*` มาตรฐานของ Material/Cupertino

### 2. Color & Gradients (ห้ามใช้สีม่วง-น้ำเงินไล่เฉดแบบ AI)
- ห้ามใช้สีม่วงไล่เฉด (`from-indigo-500 via-purple-500 to-pink-500`), ขอบเรืองแสงนีออน (unearned neon glows), หรือพื้นหลังรุ้งที่ไม่ได้อยู่ใน Design System ของโปรเจกต์
- ใช้พื้นหลังสีพื้นสะอาดตา (Neutral Slate/Zinc/Gray) และใช้สีหลัก (Primary Accent) เพียง 1 สีเฉพาะจุดที่ต้องการให้ผู้ใช้กด (Call-to-Action)

### 3. Spacing & Rhythm (ระบบระยะห่างที่สม่ำเสมอ)
- ใช้สเกลระยะห่างมาตรฐาน `4px / 8px` (`gap-2`, `gap-4`, `gap-6`, `p-4`, `p-6`) อย่างสม่ำเสมอ
- ห้ามเว้นระยะขอบด้านในของการ์ด (`padding`) น้อยกว่าระยะห่างระหว่างการ์ด (`gap`) จนเนื้อหาเบียดขอบ

### 4. Typography Hierarchy (ลำดับขั้นของตัวอักษร)
- แยกความต่างของหัวข้อหลัก (`font-semibold tracking-tight`), หัวข้อย่อย, และเนื้อหารอง (`text-sm text-muted-foreground`) ให้ชัดเจนด้วยน้ำหนักและสี ไม่ใช่แค่ขยายขนาดตัวอักษรอย่างเดียว
- ตัวเลขในตารางหรือราคาเงินต้องใส่ `tabular-nums` (`FontFeature.tabularFigures()` ใน Flutter) เพื่อให้หลักตัวเลขตรงกันเสมอ

### 5. Copywriting (ข้อความกระชับ ไม่ใช้คำโฆษณาเวอร์เกินจริง)
- ห้ามเขียนข้อความสไตล์ AI Marketing เช่น *"Revolutionize your workflow with AI-powered synergy!"*
- ใช้ข้อความที่บอกหน้าที่ตรงไปตรงมา เช่น *"บันทึกข้อมูล"*, *"รายการคำสั่งซื้อ"*, *"ไม่พบข้อมูลที่ค้นหา"*

### 6. Layout & Alignment (การจัดวางที่ได้สัดส่วน)
- หลีกเลี่ยงการวางการ์ด 3 ใบเรียงกันแบบไร้ความหมายทุกหน้า ให้เลือกโครงสร้างตามข้อมูลจริง (เช่น Table สำหรับข้อมูลเปรียบเทียบ, Split View สำหรับตั้งค่า)
- จัดแนวเส้นขอบซ้าย (Left Alignment) ของหัวข้อ ฟอร์ม และตารางให้ตรงแนวเดียวกัน

### 7. Interactive Details & States (ครบทุกสถานะการใช้งานจริง)
- ทุกหน้าจอที่ดึงข้อมูลหรือมีปุ่มกด ต้องรองรับสถานะ `Loading` (Skeleton/Spinner), `Empty State` (เมื่อยังไม่มีข้อมูล), และ `Error State` เสมอ
- ปุ่มและช่องกรอกข้อมูลต้องมี `focus-visible`, `hover`, และ `disabled` state ที่ชัดเจน

### 8. Visuals & Media (รูปภาพและสัดส่วน)
- กำหนด `aspect-ratio` และ `object-cover` ให้รูปภาพเสมอเพื่อป้องกันหน้าจอกระตุก (Layout Shift)

### 9. Subtle Motion (แอนิเมชันที่พอดี)
- ใช้ Transition เฉพาะจุดที่ช่วยบอกสถานะ (`150ms–200ms ease-out`) ห้ามใส่แอนิเมชันเด้งหรือหมุนค้างที่รบกวนสายตาผู้ใช้

### 10. Eliminate the 5 AI-Generated Design Tells (`anthropics/skills/frontend-design`)
- **ห้ามใช้ "SaaS-Card Kit" ซ้ำซาก:** ห้ามหั่นเนื้อหาทุกส่วนเป็นกล่องการ์ดมุมมนเหมือนกันหมดพร้อมเงาและพื้นหลังไล่สีจางๆ ให้ใช้เส้นแบ่งเรียบ (Flat Dividers), ตาราง (Table), หรือพื้นที่ว่าง (Whitespace) แทนการซ้อนการ์ดในกรอบ
- **ห้ามใส่ "Template Chrome" พร่ำเพรื่อ:** ห้ามใส่ป้ายตัวพิมพ์ใหญ่ `ALL-CAPS` เหนือทุกหัวข้อ, ห้ามใส่ตัวเลขกำกับ `01 / 02 / 03` ในส่วนที่ไม่ใช่ลำดับขั้นตอนจริง, ห้ามทำตัวเอียงหรือเปลี่ยนสีคำเพียงคำเดียวกลางประโยคพาดหัว, และห้ามห้อยลูกศร `→` ท้ายปุ่มทุกปุ่ม
- **UX Microcopy & Verb Consistency:** ใช้คำกริยาที่ตรงกันระหว่างปุ่มกดกับข้อความแจ้งเตือน (เช่น ปุ่ม *"บันทึกการตั้งค่า"* ➔ แจ้งเตือน *"บันทึกการตั้งค่าเรียบร้อย"*) และใช้คำศัพท์ของผู้ใช้จริงแทนศัพท์เทคนิคหลังบ้าน

### 11. Three.js / WebGL2 / WebGPU 3D Viewer Standards (`mrdoob/three.js r187+`)
- เมื่อเขียนโค้ด 3D / Three.js ให้เปิดอ่าน `.claude/skills/threejs-expert/SKILL.md` ก่อนเสมอ
- **ห้ามใช้ API ที่ถูกถอดหรือ Deprecated แล้ว:** ใช้ `three/addons/*` (ห้ามใช้ `three/examples/jsm/*`), ใช้ `HDRLoader` / `UltraHDRLoader` (ห้ามใช้ `RGBELoader`), และใช้ `renderer.outputColorSpace = THREE.SRGBColorSpace` (ห้ามใช้ `outputEncoding`)
- **บังคับจำกัดสเปกและคืนค่าการ์ดจอ:** ต้องตั้ง `renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))`, ใช้ `renderer.setAnimationLoop(animate)`, ปิดท้าย `EffectComposer` ด้วย `OutputPass`, และต้องมีฟังก์ชัน `scene.traverse()` เพื่อ `.dispose()` ทั้ง `geometry`, `material`, `texture`, และ `renderer` เมื่อปิดหน้าจอเสมอ
