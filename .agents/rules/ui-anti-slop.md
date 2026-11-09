---
description: "UI Anti-Slop & Production Design Standards (กฎออกแบบ UI สะอาดไร้กลิ่นอาย AI ห้ามวาด SVG เอง)"
paths:
  - "**/*.{tsx,jsx,vue,svelte,html,css,scss}"
  - "**/presentation/pages/**"
  - "**/presentation/widgets/**"
  - "**/core/widgets/**"
  - "**/core/layout/**"
  - "**/core/theme/**"
  - "**/components/**"
  - "**/pages/**"
  - "**/views/**"
---
# UI Anti-Slop & Production Design Standards (`heydamir/unslop` + `anthropics/skills/frontend-design`)

> **Reference Architecture:** [`heydamir/unslop`](https://github.com/heydamir/unslop) & [`anthropics/skills`](https://github.com/anthropics/skills) (`skills/frontend-design/SKILL.md` — Anti-Default Tells & 2-Pass Critique)
> **Activation:** Auto-loaded strictly on Frontend Web (`React`, `Next.js`, `Vue`) and Mobile/Desktop UI (`Flutter/Dart` presentation/widgets/theme) files. Does not consume context on backend, sync, repository, or database files.

## 1. The Iron Law of UI Implementation
> **NO GENERIC "AI SLOP" UI — APPLY ALL DESIGN DIMENSIONS & ELIMINATE THE 5 AI DESIGN TELLS IN A SINGLE PASS.**

Enforce all 11 production design dimensions on the first pass:

### 1. Icons (Zero Hand-Drawn `<svg>` & Zero Emoji Icons)
- **Strictly Forbidden:** Never write raw `<svg><path d="..."/></svg>` by hand, and never use Emojis (🚀, ✨, 📊, 🔒) as UI icons on buttons, navigation items, or section headers.
- **Required Standard Libraries:**
  - **Web (React / Next.js / Vue):** Use `lucide-react` (`lucide-icons`) for system icons and `simple-icons` for brand logos.
  - **Flutter / Dart:** Use `lucide_icons` or standard Material/Cupertino `Icons.*`.

### 2. Color & Gradients (No AI Purple-Indigo Gradients)
- Never use generic AI gradients (`from-indigo-500 via-purple-500 to-pink-500`), unearned neon glows, or rainbow backgrounds outside the project's Design System.
- Use clean neutral surfaces (Slate/Zinc/Gray) and reserve a single Primary Accent color strictly for primary interactive Call-to-Action elements.

### 3. Spacing & Rhythm (`4px / 8px` Grid)
- Maintain a strict `4px / 8px` spacing scale (`gap-2`, `gap-4`, `gap-6`, `p-4`, `p-6`).
- Never make internal card padding smaller than the outer gap between cards.

### 4. Typography Hierarchy & Tabular Figures
- Establish hierarchy through weight and contrast (`font-semibold tracking-tight` for headings, `text-sm text-muted-foreground` for secondary text), not font size alone.
- Always apply `tabular-nums` (`FontFeature.tabularFigures()` in Flutter) to prices, quantities, timers, and table columns so digits align vertically.

### 5. Copywriting (Direct Operational Labels, Zero AI Hype)
- Never write AI marketing fluff (*"Revolutionize your workflow with AI-powered synergy!"*).
- Use direct, task-accurate labels (e.g., *"บันทึกข้อมูล"*, *"รายการคำสั่งซื้อ"*, *"ไม่พบข้อมูลที่ค้นหา"*).

### 6. Layout & Alignment (Data-Driven Structure)
- Avoid defaulting to 3 identical cards in a row. Choose layouts that match the data (e.g., Tables for dense comparisons, Split Views for POS/settings).
- Maintain a single clean Left Alignment axis across headings, forms, and tables.

### 7. Interactive Details & States (Complete State Coverage)
- Every data-driven screen or action must handle `Loading` (Skeleton/Spinner), `Empty State`, and `Error State`.
- All interactive controls must have clear `focus-visible`, `hover`, and `disabled` states.

### 8. Visuals & Media (Zero Layout Shift)
- Always set explicit `aspect-ratio` and `object-cover` (`BoxFit.cover` in Flutter) on images to prevent layout shift.

### 9. Subtle Motion (Purposeful Transitions Only)
- Keep transitions purposeful and fast (`150ms–200ms ease-out`). Never add continuous bouncing or spinning animations that distract operators.

### 10. Eliminate the 5 AI-Generated Design Tells (`anthropics/skills/frontend-design`)
- **No Repetitive "SaaS-Card Kit":** Do not wrap every section in rounded cards with shadows and tinted backgrounds. Use flat dividers, tables, or whitespace instead of nested cards.
- **No "Template Chrome":** Do not place `ALL-CAPS` eyebrows above every heading, `01 / 02 / 03` badges on non-sequential items, single-word italic/color highlights mid-headline, or trailing arrows `→` on every button.
- **UX Microcopy & Verb Consistency:** Match button verbs to toast notifications (e.g., button *"บันทึกการตั้งค่า"* ➔ toast *"บันทึกการตั้งค่าเรียบร้อย"*) and never expose raw backend identifiers in user-facing messages.

### 11. Three.js / WebGL2 / WebGPU 3D Viewer Standards (`mrdoob/three.js r187+`)
- Read `.claude/skills/threejs-expert/SKILL.md` before writing any 3D / Three.js code.
- **No Deprecated APIs:** Use `three/addons/*` (never `three/examples/jsm/*`), `HDRLoader` / `UltraHDRLoader` (never `RGBELoader`), and `renderer.outputColorSpace = THREE.SRGBColorSpace` (never `outputEncoding`).
- **Mandatory GPU Cap & Disposal:** Always set `renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))`, use `renderer.setAnimationLoop(animate)`, end `EffectComposer` with `OutputPass`, and dispose `geometry`, `material`, `texture`, and `renderer` via `scene.traverse()` on unmount.
