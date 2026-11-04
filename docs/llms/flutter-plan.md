# แผน: ย้าย KepTohPOS จาก prototype HTML ไป Flutter — v0.3

> **แหล่งความจริงเดียว = `prototype/`** (`index.html`, `theme.css`, `data/mock-data.js`) ซึ่งทีมอนุมัติแล้ว
> **ยกเลิกการอ้างอิง Figma** — ไม่ต้องเปิด Figma / ไม่ใช้ Figma MCP
> อ่านคู่กับ `keptoh-blueprint.md` (กติกาธุรกิจ/สูตร) · ความคืบหน้าจดใน `TASK_STATE.md` (skill `handoff`)

## 0. หลักการ
1. **หน้าตา + flow + สูตร ต้องเหมือน prototype** (layout, สี, ข้อความไทย, ลำดับการกด, ตัวเลข) ห้ามออกแบบใหม่เอง
2. ข้อมูล = **mock JSON** แปลงจาก `prototype/data/mock-data.js` · ยังไม่มีฐานข้อมูล ไม่มี backend ไม่มี license
3. สูตรธุรกิจ port จาก JS เป็น Dart **ทีละฟังก์ชันพร้อม unit test** ผลลัพธ์ต้องเท่ากับ JS ทุกตัวเลข
4. Component กลางตามรายการในข้อ 4 · หน้าจอประกอบจาก component กลางเท่านั้น ห้ามก๊อปไปแก้เป็นอีกตัว
5. 1 PR = 1 ขั้นในข้อ 5 · ไม่เกิน ~5 ไฟล์ต่อรอบโดยไม่แจ้ง (ตาม `CLAUDE.md`) · อ่านเฉพาะส่วนของ `index.html` ที่เกี่ยวกับขั้นนั้น (ใช้ grep หา `function <ชื่อ>`) ไม่ต้องอ่านทั้งไฟล์
6. ทุกขั้นต้องรันจริงก่อนรายงาน: `flutter analyze` (0 issue) · `flutter test`

## 1. สิ่งที่ต้อง port (จาก `prototype/index.html`)
**เมนูหลัก (`VIEWS`):** โต๊ะและการขาย `tables` · บิลขาย `bills` · สต็อก `stock` · กะ `shift` · ภาพรวมกำไร `dashboard`* · รายงานรายวัน `reports`* · ตั้งค่าร้าน `setup`* (*เฉพาะ owner/manager) + หน้า Login (PIN)

| หน้า | function ใน index.html | ส่วนย่อย |
|---|---|---|
| Login | `Login` | เลือกพนักงาน + PIN (`PinDots`, `NumPad`), การ์ดสรุปวันล่าสุด |
| โต๊ะ | `TablesView` | จัดกลุ่มตามโซน, `TableCard` (ว่าง/มีลูกค้า/เกินเวลา/รอชำระ) |
| ขาย | `SaleView` | `TableChip`, `Tabs` หมวด, รายการแพ็กเกจ/สินค้า (แถว ไม่มีรูป), `PeopleRow`, `OrderLine`, `OrderSummary`, `PaymentPicker`, `PayStep`, `NoteModal`, `RemoveItemModal`, `PromptPayQR`, `Receipt` · **จ่ายก่อนกิน และ กินก่อนจ่าย** (รอบสั่ง/ปรับรายการ) |
| บิล | `BillsView` | `DataTable`, ตัวกรอง, ยอดแยกช่องทาง, `ReceiptModal` |
| สต็อก | `StockView` | `StockCount` (แป้นตัวเลขพับได้, Enter=ถัดไป), `StockPurchase`/`PurchaseModal`, `StockExpense`/`ExpenseModal`, `StockBalance` |
| กะ | `ShiftView` | `OpenShiftForm`, ปิดกะ/สรุปเงินสด |
| ภาพรวม | `DashboardView` | `Stat` 2 กลุ่ม, `ProfitChart`, `PendingBadge` |
| รายงาน | `ReportsView` | ตารางรายวัน |
| ตั้งค่า | `SetupView` | 13 หมวด (`SECS`): ข้อมูลร้าน, แพ็กเกจ, สินค้าเสริม, วัตถุดิบ, แหล่งซื้อ, โต๊ะ, พนักงาน/สิทธิ์, ช่องทางชำระ, สูตรกำไร (`CostingForm`), ค่าใช้จ่ายคงที่, ประเภทค่าใช้จ่าย, ธีม (`ThemeSettings`), ข้อมูลตัวอย่าง · ใช้ `CrudSection` + `FormFields` |

**สูตร/logic ที่ต้อง port:** `calcOrder` (ปัดเศษ, VAT none/included/excluded) · `tableTotals` · `mergeTotals` · `orderOf` · `tableDue` · `tableTimer` · `sendRound` · `adjustSent` · `sentLines` · `settle` · `computeLedger` (ต้นทุนเฉลี่ย/ล่าสุด, ประมาณจากนับรายสัปดาห์+ปรับยอด, หัวเด็ก 0.5, กำไรสุทธิ) · `seed()` (ประวัติ 30 วัน) · บทบาท `ROLE` และสิทธิ์เมนู

**ธีม:** `theme.css` = 2 ชั้น (palette ดิบ `--figma-*`/`--team-*` → token ความหมาย `--primary`, `--surface`, `--ink` …) · **ใช้แบรนด์เดียวคือ `figma`** (ตัด `team` ทิ้ง) · โหมด **สว่าง / มืด / ตามเครื่อง (auto)** ให้ผู้ใช้เลือกได้

**Responsive (ต้องเหมือน prototype):**
| ความกว้าง | layout |
|---|---|
| ≥1100 | Sidebar ตรึง 232 |
| 761–1099 | แถบไอคอนซ้าย + ปุ่มเมนูเปิด Drawer + ปุ่มผู้ใช้ |
| ≤760 | เมนูล่าง 4 รายการ + "เพิ่มเติม" |
| สูง ≤520 (มือถือแนวนอน) | แป้นตัวเลขนับสต็อกเป็นคอลัมน์ขวา |

## 2. Stack (ยืนยันแล้ว — ห้ามเพิ่ม package นอกรายการโดยไม่ถาม)
- **Flutter 3.47.9 / Dart 3.13.7** · `flutter create --platforms=android,ios,web app`
- ดูผลระหว่างพัฒนาบน Chrome / iPad · web build ใช้ส่งลิงก์ให้ทีม

| เรื่อง | package | หมายเหตุ |
|---|---|---|
| State | `flutter_bloc`, `equatable` | **Cubit** หน้าทั่วไป · **Bloc** flow ซับซ้อน (ขาย/ชำระเงิน/นับสต็อก/กะ) |
| Routing | `go_router` | path ตาม `VIEWS` เช่น `/tables`, `/setup/costing` |
| DI | `get_it` | ลงทะเบียน repository ที่ `core/di/` |
| Model | `freezed`, `json_serializable` (+ `build_runner` dev) | |
| ฟอนต์ | `google_fonts` | ใช้ฟอนต์เดียวกับ prototype (ดูลิงก์ Google Fonts ใน `<head>` ของ index.html) |
| QR พร้อมเพย์ | ถามผู้ใช้ก่อนเพิ่ม (เช่น `qr_flutter`) | |
| ทดสอบ | `flutter_test` (unit/widget/golden), `bloc_test`, `mocktail` | |
| Lint | `very_good_analysis` | |

## 3. โครงโฟลเดอร์ (Clean Architecture แบบ feature-first)
```
app/
  lib/
    main.dart · app.dart          ← MaterialApp.router + BlocProviders ระดับแอป
    core/
      theme/                      ← tokens.dart (แปลงจาก theme.css), app_theme.dart (แบรนด์ figma × light/dark/auto)
      widgets/                    ← component กลาง 1 ไฟล์ต่อ 1 component (ข้อ 4)
      layout/                     ← AppShell responsive (sidebar / rail+drawer / bottom nav)
      router/ · di/ · utils/      ← utils: baht(), fmtQ(), วันที่ไทย
    domain/                       ← สูตรกลางที่หลาย feature ใช้: order_calc.dart, ledger.dart, settle.dart (Dart ล้วน ไม่ import Flutter)
    features/<feature>/           ← auth, tables, sale, bills, stock, shift, dashboard, reports, setup
      presentation/               ← pages/, widgets/, bloc/ หรือ cubit/
      domain/                     ← entities/, repositories/ (abstract)
      data/                       ← models/, datasources/ (อ่าน assets/mock), repositories/ (impl, เก็บในหน่วยความจำ)
  assets/mock/                    ← JSON แปลงจาก mock-data.js
  test/{unit,bloc,widget,golden}/
```
กติกา: ไฟล์ละไม่เกิน ~300 บรรทัด · UI → Bloc/Cubit → Repository (abstract) เท่านั้น ห้าม widget อ่าน JSON เอง · `domain/` ห้าม import Flutter

## 4. Component กลาง (ชื่อเดียวกับ prototype ให้ค้นเทียบได้)
| กลุ่ม | widget (prototype → Flutter) |
|---|---|
| Layout | `AppShell`, `NavPanel`/`NavDrawer`, `PageHeader`, `Toolbar`, `SearchBox`, `Avatar`, `Drawer` |
| Input | `Btn`, `Field`, `Stepper`, `Seg`, `Tabs`, `Dropdown`, `NumPad`, `PinDots` |
| Display | `Pill`, `Stat`, `DataTable`, `Pagination`, `Empty`, `ResultState`, `Icon` (ชุด `ICONS`) |
| Overlay | `Modal`, `Confirm`, toast |
| Domain | `TableCard`, `TableChip`, `PeopleRow`, `OrderLine`, `PaymentPicker`, `OrderSummary`, `PayStep`, `PromptPayQR`, `Receipt`, `CrudSection`, `FormFields`, `ProfitChart` |

## 5. ขั้นงาน (1 ขั้น = 1 PR, ทำตามลำดับ)
| # | งาน | เสร็จเมื่อ |
|---|---|---|
| F0 | สร้าง `app/` + package ข้อ 2 + โครงข้อ 3 + `tokens.dart`/`app_theme.dart` จาก `theme.css` + แปลง `mock-data.js` → `assets/mock/*.json` | `flutter analyze` 0 issue, แอปเปิดหน้าว่างได้, สลับโหมดสว่าง/มืด/auto ได้ |
| F1 | port สูตรใน `lib/domain/` + model + unit test (ตัวเลขคาดหวังได้จากการรันฟังก์ชัน JS เดิมใน prototype) | unit test ผ่านทั้งหมด ตัวเลขตรง JS |
| F2 | component กลางข้อ 4 (กลุ่ม Layout/Input/Display/Overlay) + `AppShell` responsive 3 แบบ + router | widget test ของแต่ละ component + golden ของ shell 3 ขนาด |
| F3 | Login (PIN) + กะ (เปิด/ปิด) + สิทธิ์ตามบทบาท | flow login → เปิดกะ → เห็นเมนูตามสิทธิ์ |
| F4 | โต๊ะ + ขาย + ชำระเงิน + ใบเสร็จ (ทั้งจ่ายก่อนและกินก่อนจ่าย) | bloc test ครบ flow · ยอดตรง prototype |
| F5 | บิล | ตัวกรอง/ยอดแยกช่องทาง/ดูใบเสร็จ |
| F6 | สต็อก: นับของเหลือ (แป้นพับได้) / ซื้อของ / ค่าใช้จ่าย / คงเหลือ | นับครบแล้วบันทึกปิดวันได้ |
| F7 | ภาพรวม + รายงาน (กราฟกำไร) | ตัวเลขตรงกับ prototype บน mock data ชุดเดียวกัน |
| F8 | ตั้งค่า 13 หมวด | CRUD ทุกหมวด, ค่าเปลี่ยนแล้วมีผลกับหน้าขาย/สูตร |
| F9 | ตรวจรวม: เทียบทุกหน้ากับ prototype 3 ขนาด (1366×1024, 820×1180, 390×844) + build web ให้ทีมดู | ทีมยืนยันว่าเหมือน prototype |

**วิธีเทียบหน้าตา:** เปิด `prototype/index.html` ในเบราว์เซอร์ขนาดเดียวกับแอป แล้วเทียบทีละหน้า (ภาพอ้างอิงเก็บที่ `app/test/golden/reference/` ถ้ามี)

## 6. สิ่งที่ตัดสินใจแล้ว
- โค้ดอยู่ `app/` ใน repo นี้ · พัฒนาบนเครื่อง local ของผู้ใช้ (Flutter พร้อมแล้ว)
- UI/UX ตาม prototype · ไม่ใช้ Figma
- ธีม: แบรนด์ `figma` อย่างเดียว · โหมดสว่าง/มืด/auto · หมวด "ธีมและการแสดงผล" ในตั้งค่า เหลือแค่เลือกโหมด
- BLoC/Cubit + Repository + go_router + get_it · ข้อมูล mock JSON เก็บในหน่วยความจำ (เปิดแอปใหม่ = เริ่มจาก mock)

## 7. ภาพรวมระยะยาว (บันทึกไว้เป็นทิศทาง — **ไม่อยู่ในขอบเขต F0–F9 ห้ามเขียนโค้ดเผื่อ**)
- ผู้ให้บริการคือ **สำนักงานบัญชี** ติดตั้ง POS ให้ร้านลูกค้า เพื่อได้ข้อมูลขาย/ต้นทุนของร้านโดยไม่ต้องขอ · เริ่มจากร้านหมูกระทะ
- **แอปติดตั้งในเครื่อง** (ไม่ใช้ cloud สำหรับการขาย) ฐานข้อมูลในเครื่อง (SQLite/`drift`) แทน repository แบบ mock · ไม่ใช้ Redis/Kafka
- **License key มีวันหมดอายุ** (key เซ็นลายเซ็นดิจิทัล ตรวจแบบ offline, กันย้อนนาฬิกา, grace period, หมดอายุแล้วยังดู/ส่งออกข้อมูลได้)
- ยังต้องตัดสินใจภายหลัง: วิธีส่งข้อมูลให้สำนักงาน, อุปกรณ์ร้าน, รูปแบบไฟล์ให้ตรงโปรแกรมบัญชีของสำนักงาน, สัญญา/PDPA
