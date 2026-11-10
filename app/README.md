# เก็บโต๊ะ POS — Flutter Application (`app/`)

โฟลเดอร์ `app/` คือโค้ดฝั่ง Frontend ของระบบ **เก็บโต๊ะ POS (KepToh POS V2)** พัฒนาด้วย **Flutter Web / Tablet (`3.47.9`)** ออกแบบตามสถาปัตยกรรม **Feature-First + BLoC + Offline-First Outbox (`Drift` / `IndexedDB`)**

> สำหรับภาพรวมระบบทั้งหมด, แผนภาพ Data Flow Diagrams, โครงสร้างฐานข้อมูล Supabase และขั้นตอนการ Deploy บน Vercel / Cloudflare โปรดดูที่ไฟล์หลัก [`../README.md`](../README.md)

---

## 1. โครงสร้างโค้ดภายใน `app/lib/`

```text
app/lib/
├── main.dart                     # จุดเริ่มต้นของแอป, ตั้งค่า DI, ตรวจสอบ POS_BACKEND และเปิดหน้า Onboarding / POS
├── core/
│   ├── di/                       # Dependency Injection ด้วย get_it (service_locator.dart)
│   ├── offline/                  # ระบบ Offline-First: Drift SQLite/Wasm (OutboxQueue, SnapshotCache, CachedStaffPins, OutboxSyncService)
│   ├── router/                   # GoRouter navigation & Role-based route guards
│   ├── supabase/                 # Supabase client, ShopRealtimeService (500ms debounce), Turnstile Captcha, Offline PIN crypto
│   ├── theme/                    # สี (Charcoal #20242C / Orange #FF7A00) และฟอนต์ (Anuphan / IBM Plex Sans Thai)
│   └── utils/                    # ฟังก์ชันคำนวณบัญชี/สต็อก (computeLedger, roundQty, bahtSmart, CSV Exporter)
├── data/
│   ├── datasources/              # MockPosDataSource (โหมดสาธิต) และ SupabasePosDataSource (เชื่อมต่อ RPC จริง)
│   ├── models/                   # Immutable Data Models (PosSnapshot, Bill, TableSession, Ingredient, Shift, ShopSettings ฯลฯ)
│   └── repositories/             # PosRepository & CachingPosRepository (เชื่อม Local Cache + OutboxQueue)
├── features/
│   ├── onboarding/               # หน้า Login (LINE/Google), สร้างร้านใหม่, ผูกเครื่องแคชเชียร์ (Pairing Code) และกดรหัส PIN
│   ├── pos/                      # หน้าผังโต๊ะ, เปิดโต๊ะ, สั่งของเพิ่ม (Addons), ย้าย/รวมโต๊ะ, ชำระเงิน และใบเสร็จ/ใบกำกับภาษี
│   ├── bills/                    # หน้าประวัติบิล, ยกเลิกบิล (Void), ออกบิลใหม่แทนใบเดิม (Reissue), และขอใบกำกับภาษีเต็มรูป
│   ├── stock/                    # หน้านับของเหลือปิดร้าน, รับของเข้า (คัดลอกบิลเดิม), และสถานะสต็อก/จุดสั่งซื้อ (Par Level)
│   ├── shift/                    # หน้าเปิดกะ, บันทึกรายจ่ายหน้าร้าน, และปิดกะกระทบยอดเงินสด
│   ├── dashboard/                # หน้าภาพรวมผู้บริหาร (กำไรสุทธิ, ต้นทุน/หัว, % Food Cost, กราฟรายวัน)
│   ├── reports/                  # หน้ารายงานรายวัน, รายงานภาษีขาย (Sales Tax Report), สรุปยอดรายเครื่อง และส่งออก .CSV
│   ├── settings/                 # หน้าตั้งค่าร้าน/ใบเสร็จ/VAT, แพ็กเกจ, ขายเสริม, วัตถุดิบ, โต๊ะ, พนักงาน, ช่องทางชำระ และเครื่องแคชเชียร์
│   └── dev/                      # หน้าคลังตัวอย่าง Shared Components (/dev/components)
└── shared/
    └── widgets/                  # คอมโพเนนต์กลางที่ใช้ซ้ำทั้งแอป (Confirm, FormModal, NumPad, PendingBadge, ResponsiveFormRow, TaxIdBranchInput)
```

---

## 2. ตัวแปร `--dart-define` ที่รองรับ

| ตัวแปร | ค่าที่รองรับ | คำอธิบาย |
| :--- | :--- | :--- |
| `POS_BACKEND` | `mock` (ค่าเริ่มต้น) \| `supabase` | เลือกแหล่งข้อมูลระหว่างข้อมูลจำลองในเครื่อง (`mock`) หรือเชื่อมฐานข้อมูล Supabase จริง (`supabase`) |
| `SUPABASE_URL` | URL ของ Supabase | จำเป็นเมื่อ `POS_BACKEND=supabase` (เช่น `http://127.0.0.1:54321` หรือ `https://<ref>.supabase.co`) |
| `SUPABASE_ANON_KEY` | Public Anon Key | จำเป็นเมื่อ `POS_BACKEND=supabase` |
| `CAPTCHA_SITE_KEY` | Turnstile Site Key | ตัวเลือกเสริม — หากระบุจะเปิดใช้งาน Cloudflare Turnstile ตอนกดผูกเครื่องแคชเชียร์ |

---

## 3. คำสั่งที่ใช้บ่อยในการพัฒนา (Developer Commands)

### รันแอปบน Chrome
```bash
# โหมดข้อมูลจำลอง (Mock Mode)
flutter run -d chrome --web-port 3000

# โหมดเชื่อม Local Supabase Docker
eval "$(supabase status -o env | grep -E '^(API_URL|ANON_KEY)=')"
flutter run -d chrome --web-port 3000 \
  --dart-define=POS_BACKEND=supabase \
  --dart-define=SUPABASE_URL="$API_URL" \
  --dart-define=SUPABASE_ANON_KEY="$ANON_KEY"
```

### สร้างโค้ด Drift Database ใหม่ (เมื่อแก้ไขตารางใน `lib/core/offline/local_database.dart`)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### รันการตรวจสอบโค้ดและชุดทดสอบ (Testing)
```bash
# 1. วิเคราะห์โค้ดตามกฎ very_good_analysis
flutter analyze lib test

# 2. รันเทสต์ไฟล์เดียว (Tier 1 — รันหลังแก้โค้ดทุกครั้ง)
flutter test test/unit/<ชื่อไฟล์>_test.dart

# 3. รันชุดทดสอบ Unit + BLoC + Widget ทั้งหมด
flutter test test/unit test/bloc test/widget

# 4. รัน Golden Visual Regression Tests (บน macOS)
flutter test test/golden

# 5. อัปเดตไฟล์ภาพ Golden PNG (เฉพาะเมื่อตั้งใจปรับดีไซน์ UI)
flutter test --update-goldens test/golden
```

---

## 4. ข้อควรระวังในการเขียน Widget Test ของโปรเจกต์นี้
- หน้าจอ POS แบบหลายคอลัมน์ต้องกำหนดขนาดหน้าจอเป็นระดับ Desktop/iPad (`tester.binding.setSurfaceSize(const Size(1280, 800))`) ก่อนเรียก `pumpWidget` เสมอ เพื่อป้องกัน `RenderFlex overflow` บนขนาดหน้าจอเริ่มต้น `800x600` ของ `flutter test`
- ตรวจสอบคอมโพเนนต์กลางที่มีอยู่แล้วใน [`lib/shared/widgets/`](lib/shared/widgets/) (หรือดูตัวอย่างผ่าน Route `/dev/components`) ก่อนสร้างคอมโพเนนต์ใหม่ทุกครั้ง
