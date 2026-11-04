# แผน: ย้ายไป Flutter — แกะ UI จาก Figma ให้ตรง 100% ก่อน แล้วค่อยปรับเป็น KepTohPOS — v0.2 (ยืนยันแล้ว: ระยะ A + BLoC)

> อ่านคู่กับ `keptoh-blueprint.md` (กติกาธุรกิจ) · prototype HTML (`prototype/`) ทีมอนุมัติแล้ว ใช้เป็น **ต้นแบบ flow และสูตรคำนวณ** ไม่ต้องแก้ต่อ
> Figma: [Makaryo POS (Community)](https://www.figma.com/design/zWOF0W01I3hFtoKNXAFmVZ/Makaryo-Point-Of-Sales-Free--Community-?node-id=1-3517) · fileKey `zWOF0W01I3hFtoKNXAFmVZ` · หน้า `1:3517 🍏 UI Design`
> ความคืบหน้าจดใน `TASK_STATE.md` (skill `handoff`) เพื่อส่งต่องานข้ามโมเดล/เครื่อง

## 0. หลักการ
1. **ระยะ A = แกะ Figma ตรงตัว** ใช้ข้อความ รูป และข้อมูลตัวอย่างแบบใน Figma (เบอร์เกอร์, ภาษาอังกฤษ, $) ห้ามดัดแปลงเป็นของร้านในระยะนี้ เพื่อวัดผลได้ว่า "ตรง Figma" จริง
2. **ระยะ B = ปรับเป็น KepTohPOS** เปลี่ยนเนื้อหา/flow ทีหลัง โดยใช้ widget ชุดเดียวกับระยะ A ห้ามก๊อปไปแก้เป็นอีกตัว
3. ทุกค่า (สี ระยะ ขนาดตัวอักษร มุมโค้ง เงา) มาจาก **token** ที่ถอดจาก Figma ห้ามใส่เลขลอยในหน้าจอ
4. "ตรง 100%" วัดด้วย **golden test** เทียบภาพ Figma ที่ขนาด 1366×1024 (ดูข้อ 6) ไม่ใช้สายตาอย่างเดียว
5. 1 PR = 1 ขั้นในข้อ 5 · ไม่เกิน ~5 ไฟล์ต่อรอบโดยไม่แจ้ง (ตาม `CLAUDE.md`)
6. แบ่งงานโมเดล: **Opus** ถอดสเปกทีละหน้าเป็นไฟล์ `docs/llms/figma-spec/<screen>.md` · **Sonnet** เขียนโค้ดตามสเปก

## 1. สิ่งที่มีใน Figma (สำรวจแล้ว)
ทุก frame เป็น **1366×1024 (แท็บเล็ตแนวนอน)** — **ไม่มีแบบมือถือ ไม่มีแนวตั้ง**

| กลุ่ม | frame (node id) | จำนวน |
|---|---|---|
| Login | `2005:3955` | 4 สถานะ |
| หน้าหลัก | Cashier `68:14268` · Table `275:21181` · History `274:11946` · Report `275:12839` · Supply list `207:8812` · Supply grid `2001:5973` (ทั้งหมดใน `2005:3948`) | 6 |
| ชำระเงิน | Credit Card (`2005:3913–3915`) · Cash `2005:3925` · QRIS `2005:3926` | 3 + 4 + 3 |
| Dropdown | Select Table · Order Type · Floor (`2005:3949`) | 3 |
| Modal แก้ไข | Edit Customer `2005:3950` · Customer Notes `2005:3951` · Menu Notes `2005:3952` | 2 + 2 + 2 |
| ตัวกรอง | History Filter · Supply Filter (`2005:3953`) | 2 |
| Empty state | Order Panel · Order List · Report · History · Supply list/grid (`2005:3954`) | 6 |

รวม ≈ **37 สถานะหน้าจอ**

**โครงหน้า (Cashier):** Header สูง 88 (ปุ่มเปิด sidebar, ค้นหา, ปุ่ม "Close Order") · พื้นที่หลักกว้าง 970 (Order List แนวนอน → แท็บหมวด → grid เมนู 4 คอลัมน์) · **Order Panel ขวา 396** (ลูกค้า, dropdown โต๊ะ/ประเภท, รายการ+stepper, สรุปยอด, วิธีชำระ 3 ช่อง, ปุ่ม Place Order)
**Sidebar:** กว้าง 365 เป็น **drawer ซ้อนทับ** พร้อมฉากมืด (ไม่ได้ตรึง) — มีโลโก้, การ์ดกะพนักงาน, เมนู 5 รายการ (Cashier, Table, Report, History, Supply), Log out

**Component ที่ Figma ประกาศไว้:** `Header`, `sidebar-left`, `Tab-Cashier`, `Tab - Burger`, `Menu Label`, `Icon`, `Order Status`, `Order Status Indicator Icon`, `Stock Status`, `Title`

**Token สี (variables):**
`Orange/50 #fff4ed` `Orange/100 #ffe6d4` `Orange/500 #fe4e10` `Orange/600 #ef3408` · `Neutral/50 #f8f8f8` `/100 #e7e7e7` `/300 #b0b0b0` `/400 #888888` `/500 #6d6d6d` `/600 #5d5d5d` `/900 #3d3d3d` `/950 #000000` · `Gray/100 #f2f4f7` `/200 #e4e7ec` `/400 #98a2b3` · `Green #f0fdf4` `#dcfce7` `#16a34a` · `Red #dc2626` · `Dark #141B34` · `Burger Brand/100 #ffe9e1` `/700 #f85625`

**ยังต้องตรวจในขั้น 0:** ฟอนต์จริง, ชุดไอคอน (ดูเหมือน Hugeicons), ขนาดตัวอักษร/ระยะ/เงา, สิทธิ์ใช้รูปอาหารในไฟล์ community

## 2. Stack (ยืนยันแล้ว — ห้ามเพิ่ม package นอกรายการโดยไม่ถาม)
- เครื่องพัฒนา: **Flutter 3.47.9 / Dart 3.13.7** (ตั้ง `environment.sdk` ใน pubspec ให้ตรง)
- `flutter create --platforms=android,ios,web` · ระยะ A รัน/ดูผลบน Chrome หรือ iPad ได้ · web ใช้ส่งลิงก์ให้ทีมดู
- **ข้อมูลระยะ A = mock JSON เท่านั้น** ยังไม่มีฐานข้อมูล ไม่มี backend ไม่มี license

| เรื่อง | package | หมายเหตุ |
|---|---|---|
| State | `flutter_bloc`, `equatable` | **Cubit** หน้าทั่วไป (ตั้งค่า/รายการ/ตัวกรอง) · **Bloc** flow ซับซ้อน (ออเดอร์/ชำระเงิน) |
| Routing | `go_router` | |
| DI | `get_it` | ลงทะเบียน repository ที่เดียว (`core/di/`) |
| Model | `freezed`, `json_serializable` (+ `build_runner` dev) | model immutable + อ่าน mock JSON |
| ฟอนต์/ไอคอน | ตามผลตรวจขั้น A0 | ให้ตรง Figma |
| ทดสอบ | `flutter_test` (unit/widget/**golden**), `bloc_test`, `mocktail` | |
| Lint | `very_good_analysis` | `flutter analyze` ต้อง 0 issue |

## 3. โครงโฟลเดอร์ (Clean Architecture แบบ feature-first, แยกไฟล์ตั้งแต่แรก)
```
app/                              ← โปรเจกต์ Flutter (repo เดียวกับ prototype)
  lib/
    main.dart · app.dart          ← MaterialApp.router + BlocProviders ระดับแอป
    core/
      theme/                      ← tokens.dart (สี/ระยะ/มุม/เงา), typography.dart, app_theme.dart
      widgets/                    ← component กลาง 1 ไฟล์ต่อ 1 component
      layout/                     ← AppShell (Header + Sidebar drawer + body)
      router/ · di/ · utils/
    features/<feature>/           ← login, cashier, table, history, report, supply, payment
      presentation/               ← pages/, widgets/, bloc/ หรือ cubit/
      domain/                     ← entities/, repositories/ (abstract)
      data/                       ← models/ (freezed), datasources/ (mock_*.dart อ่าน assets/mock), repositories/ (impl)
  assets/{images,icons,mock}/
  test/{unit,bloc,widget,golden}/ + test/golden/figma/   ← ภาพอ้างอิงจาก Figma
docs/llms/figma-spec/             ← สเปกทีละหน้า (Opus เขียน)
```
กติกา:
- ไฟล์ละไม่เกิน ~300 บรรทัด · หน้าจอประกอบจาก `core/widgets` เท่านั้น
- UI → Bloc/Cubit → Repository (abstract) เท่านั้น ห้าม widget อ่าน JSON หรือเรียก datasource ตรง
- ภายหลังเปลี่ยนแหล่งข้อมูล (SQLite) ได้โดยเปลี่ยนแค่ `data/` ไม่แตะ UI

## 4. Component กลาง (ถอดจาก Figma)
| กลุ่ม | widget |
|---|---|
| Layout | `AppShell`, `AppHeader` (88), `AppSidebar` (drawer 365 + scrim), `ShiftCard`, `PageTitle` (หัวข้อ+คำอธิบาย+ปุ่มขวา) |
| Input | `PrimaryButton`/`SecondaryButton`/`IconBtn`, `SearchField`, `AppDropdown`, `QtyStepper`, `CategoryTab` (`Tab-Cashier`), `PaymentMethodTile`, `PinPad` (login), `TextArea` (notes) |
| Display | `OrderCard` + `OrderStatusBadge`, `MenuCard` + `MenuLabel`, `TableTile` (สถานะ Available/Occupied), `AppDataTable` + `AppPagination`, `StockStatusBadge`, `SupplyCard`, `SummaryRows`, `EmptyState` |
| Overlay | `AppModal` (Edit customer/notes), `FilterPanel`, `DropdownMenuOverlay` |
| Domain (Figma) | `OrderPanel` (396) + `OrderLineItem`, `PaymentSheet` (Card/Cash/QRIS ตามขั้นตอนใน Figma) |

## 5. ขั้นงาน (1 ขั้น = 1 PR)
### ระยะ A — แกะ Figma
| # | งาน | ผู้ทำ | เสร็จเมื่อ |
|---|---|---|---|
| A0 | ตรวจฟอนต์/ไอคอน/สเปกด้วย `get_design_context` · export ภาพอ้างอิง 37 สถานะ + รูป/ไอคอน · เขียน `figma-spec/_tokens.md` | Opus | มีไฟล์ token + ภาพอ้างอิงครบ |
| A1 | สร้าง `app/` (flutter create, web) + package ข้อ 2 + theme/tokens + โครงโฟลเดอร์ + CI `flutter analyze`/`flutter test` | Sonnet | `flutter analyze` 0 issue, แอปเปิดได้ |
| A2 | `AppShell`, `AppHeader`, `AppSidebar` + router 6 หน้า (หน้าว่าง) | Sonnet | golden ของ shell ผ่าน |
| A3 | **Cashier** (OrderCard, CategoryTab, MenuCard, OrderPanel, Stepper, PaymentMethodTile) | Sonnet | golden Cashier ผ่าน |
| A4 | Payment: Credit Card 3 · Cash 4 · QRIS 3 สถานะ | Sonnet | golden 10 สถานะผ่าน |
| A5 | Dropdown 3 · Edit Customer/Notes/Menu Notes 6 สถานะ | Sonnet | golden ผ่าน |
| A6 | **Table** + Pagination | Sonnet | golden ผ่าน |
| A7 | **History** + **Report** (`AppDataTable`) + History Filter | Sonnet | golden ผ่าน |
| A8 | **Supply** list/grid + Supply Filter + StockStatus | Sonnet | golden ผ่าน |
| A9 | **Login** 4 สถานะ + Empty state 6 แบบ | Sonnet | golden ผ่านครบ 37 สถานะ |
| A10 | ตรวจรวม + deploy Flutter web บน Vercel ให้ทีมดู | Opus ตรวจ | ทีมยืนยันว่า "ตรง Figma" |

ก่อนแต่ละขั้น A3–A9: Opus เขียน `figma-spec/<screen>.md` (โครง layout, ขนาด/ระยะทุกกล่อง, component ที่ใช้, สถานะ) ให้ Sonnet ทำตาม

### ระยะ B — ปรับเป็น KepTohPOS (วางแผนละเอียดหลังจบ A)
- B1 port สูตรจาก prototype เป็น Dart ใน `domain/` พร้อม unit test ตัวเลขเดียวกับเทสต์ JS เดิม (`calcOrder`, `settle`, `computeLedger` ฯลฯ)
- B2 ภาษาไทย + ฟอนต์ไทย, บาท, mock data ร้านหมูกระทะ
- B3 แมปหน้า: Cashier→ขาย (แพ็กเกจบุฟเฟต์/จำนวนหัว, จ่ายก่อน/หลังกิน), Table→โต๊ะ+เวลา, History→บิล, Report→กำไรขาดทุน, Supply→สต็อก+นับของเหลือ
- B4 หน้าที่ Figma ไม่มี (ตั้งค่า, ค่าใช้จ่าย, นับสต็อกเร็ว) ประกอบจาก widget ระยะ A
- B5 ขนาดจอเล็ก/มือถือ/แนวตั้ง (Figma ไม่มี ต้องออกแบบเพิ่ม)

## 6. วิธีวัด "ตรง Figma"
- Golden test ตั้งขนาด `1366×1024` ใช้ฟอนต์จริง (โหลดใน test) และ mock data ตรง Figma
- สคริปต์เทียบภาพ golden กับภาพ export จาก Figma → รายงาน % pixel ต่าง + ภาพ diff
- เกณฑ์: layout/ตำแหน่ง/ขนาดตรง (ต่างไม่เกิน 1–2px) · สีตรง token · การเรนเดอร์ตัวอักษรที่ต่างเล็กน้อยระหว่าง Figma กับ Flutter ยอมรับได้ (ตรงพิกเซล 100% ทางเทคนิคเป็นไปไม่ได้เพราะ engine วาดฟอนต์ต่างกัน)

## 7. สภาพแวดล้อม
- container ของ Claude บนคลาวด์ตอนนี้ **ยังไม่มี Flutter SDK** → ทำบนเครื่องผู้ใช้ (clone repo) หรือเพิ่มการติดตั้ง Flutter ใน setup script ของ environment
- ทุกขั้นต้องรันจริงก่อนรายงาน: `flutter analyze` · `flutter test` · (golden) `flutter test test/golden`

## 8. สิ่งที่ตัดสินใจแล้ว
- โค้ดอยู่ `app/` ใน repo นี้ · พัฒนาบนเครื่อง local ของผู้ใช้ (Flutter พร้อมแล้ว)
- BLoC/Cubit + Repository + go_router + get_it (ข้อ 2)
- ระยะ A = UI ตรง Figma + mock JSON เท่านั้น

## 9. ภาพรวมระยะยาว (บันทึกไว้เป็นทิศทาง — **ไม่อยู่ในขอบเขตระยะ A/B ห้ามเขียนโค้ดเผื่อ**)
- ผู้ให้บริการคือ **สำนักงานบัญชี** ติดตั้ง POS ให้ร้านลูกค้า เพื่อได้ข้อมูลขาย/ต้นทุนของร้านโดยไม่ต้องขอ · เริ่มจากร้านหมูกระทะ
- แนวทาง: **แอปติดตั้งในเครื่อง** (ไม่ใช้ cloud สำหรับการขาย) ฐานข้อมูลในเครื่อง (SQLite/`drift`) · ไม่ใช้ Redis/Kafka
- **License key มีวันหมดอายุ** (key เซ็นลายเซ็นดิจิทัล ตรวจได้แบบ offline, กันย้อนนาฬิกา, มี grace period, หมดอายุแล้วยังดู/ส่งออกข้อมูลได้)
- ยังต้องตัดสินใจภายหลัง: วิธีส่งข้อมูลให้สำนักงาน (ส่งไฟล์เอง vs ส่งขึ้นเครื่องสำนักงานอัตโนมัติ), อุปกรณ์ร้าน, รูปแบบไฟล์ให้ตรงโปรแกรมบัญชีของสำนักงาน, สัญญา/PDPA
