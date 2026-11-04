# ภาพอ้างอิง Figma (`design/figma/`)

> ใช้สำหรับเทียบ **โครงหน้า ตำแหน่ง ขนาด และสไตล์ของ Component** (ความกว้างอ้างอิง `1366×1024`) ร่วมกับเนื้อหา/flow/สูตรจาก `prototype/index.html` ตามแผน `docs/llms/flutter-plan.md` (v0.4)

## 1. ตารางแมปไฟล์ภาพกับหน้าจอและสถานะในแอป

| ไฟล์ภาพ | ขนาด (px) | หน้าจอใน Prototype (`VIEWS`) | รายละเอียด / สถานะในภาพ |
|---|---|---|---|
| `login.png` | `5764×1024` | `Login` | รวม 4 สถานะเรียงกัน: (1) หน้ากรอก PIN + NumPad, (2) เปิด Dropdown เลือกพนักงาน, (3) หน้าลืม PIN (กรอกอีเมล), (4) หน้าแจ้งส่ง PIN แล้ว |
| `table.png` | `1366×1024` | `TablesView` (`tables`) | หน้าผังโต๊ะหลัก แสดงการ์ดโต๊ะ (`TableCard`: Available / Used) + ค้นหา + เลือกโซน (Floor) + Pagination |
| `table_sidebar.png` | `1366×1024` | `TablesView` + `NavDrawer` | หน้าโต๊ะเมื่อกดเปิด Sidebar เลื่อนทับ (`365px`) พร้อมฉากมืด (`scrim`) |
| `dropdown_table_order_floor.png` | `4282×1024` | `SaleView` / `TablesView` | รวม 3 สถานะ Dropdown: (1) เลือกโต๊ะ (`Select Table`), (2) เลือกประเภทออเดอร์ (`Order Type`), (3) เลือกโซน/ชั้น (`Floor`) ในหน้าโต๊ะ |
| `cashier.png` | `1366×1024` | `SaleView` | หน้าขายหลัก: แถบออเดอร์ด้านบน, หมวดสินค้า (`Tabs`), ตารางการ์ดสินค้ามีรูป (`ProductCard`), และแผงสรุปออเดอร์ด้านขวา (`396px`) |
| `cashier_sidebar.png` | `1366×1024` | `SaleView` + `NavDrawer` | หน้าขายเมื่อกดเปิด Sidebar เลื่อนทับ (`365px`) พร้อมฉากมืด |
| `modal_edit_customer.png` | `2832×1024` | `SaleView` (`PeopleRow`) | รวม 2 สถานะ Modal ข้อมูลลูกค้า/จำนวนคน (ว่าง และ กรอกแล้ว) พร้อมแป้นพิมพ์ |
| `modal_edit_customer_notes.png` | `2832×1024` | `SaleView` (`NoteModal`) | รวม 2 สถานะ Modal หมายเหตุท้ายบิล/ลูกค้า (ว่าง และ กรอกแล้ว) |
| `modal_edit_menu_notes.png` | `2832×1024` | `SaleView` (`NoteModal`) | รวม 2 สถานะ Modal หมายเหตุรายเมนู (ว่าง และ กรอกแล้ว) |
| `payment_cash.png` | `5740×1024` | `SaleView` (`PayStep` - เงินสด) | รวม 4 สถานะชำระเงินสดในแผงขวา: (1) รอกรอกยอดรับเงิน, (2) กรอกยอดรับเงินและคำนวณเงินทอน, (3) ชำระเงินสำเร็จ (`ResultState`), (4) ชำระเงินไม่สำเร็จ |
| `payment_qris.png` | `4282×1024` | `SaleView` (`PromptPayQR`) | รวม 3 สถานะชำระด้วย QR (ใช้เป็นต้นแบบ PromptPay QR): (1) แสดง QR Code, (2) ชำระสำเร็จ, (3) ชำระไม่สำเร็จ |
| `payment_card_waiting.png` | `1366×1024` | `SaleView` (`PayStep` - โอน/บัตร) | สถานะรอการชำระเงินผ่านบัตร/โอนเงิน (`Waiting for payment`) ในแผงขวา |
| `payment_card_success.png` | `1366×1024` | `SaleView` (`PayStep` - โอน/บัตร) | สถานะชำระเงินผ่านบัตร/โอนเงินสำเร็จ (`Payment Success`) |
| `payment_card_failed.png` | `1366×1024` | `SaleView` (`PayStep` - โอน/บัตร) | สถานะชำระเงินผ่านบัตร/โอนเงินไม่สำเร็จ (`Payment Failed`) |
| `history.png` | `1366×1024` | `BillsView` (`bills`) | หน้าประวัติบิลขาย (`DataTable` แสดงรายการบิล + ปุ่มค้นหา/ตัวกรอง + Pagination) |
| `history_sidebar.png` | `1366×1024` | `BillsView` + `NavDrawer` | หน้าประวัติบิลขายเมื่อเปิด Sidebar เลื่อนทับ |
| `filter_history_supply.png` | `2832×1024` | `BillsView` / `StockView` | รวม 2 สถานะเมนูตัวกรอง (`Filter` popover): (1) ตัวกรองหน้า History/บิลขาย, (2) ตัวกรองหน้า Supply/สต็อก |
| `report.png` | `1366×1024` | `ReportsView` (`reports`) | หน้ารายงานตารางสรุปรายการ (`DataTable` + ปุ่มส่งออก + Pagination) |
| `report_sidebar.png` | `1366×1024` | `ReportsView` + `NavDrawer` | หน้ารายงานเมื่อเปิด Sidebar เลื่อนทับ |
| `supply_list.png` | `1366×1024` | `StockView` (`stock` - คงเหลือ/ซื้อของ) | หน้าสต็อกวัตถุดิบแบบตาราง (`DataTable`) พร้อมป้ายสถานะ (`Pill`: ปกติ / ใกล้หมด / หมด) |
| `supply_grid.png` | `1366×1024` | `StockView` (`stock` - คงเหลือ/ซื้อของ) | หน้าสต็อกวัตถุดิบแบบการ์ด (`Grid`) แสดงรูป ชื่อ วันที่อัปเดต และจำนวนคงเหลือ |
| `supply_sidebar.png` | `1366×1024` | `StockView` + `NavDrawer` | หน้าสต็อกเมื่อเปิด Sidebar เลื่อนทับ |
| `empty_states.png` | `9291×1024` | ทุกหน้า (`Empty`) | รวม 6 สถานะหน้าว่าง (`Empty State`): (1) ยังไม่เลือกรายการในแผงออเดอร์, (2) ไม่มีออเดอร์ในหน้าขาย, (3) ไม่มีประวัติบิล, (4) ไม่มีข้อมูลรายงาน, (5) สต็อกว่างแบบตาราง, (6) สต็อกว่างแบบการ์ด |

---

## 2. หน้าจอและส่วนย่อยที่ไม่มีภาพใน Figma (ไม่ต้อง Export เพิ่ม)

หน้าจอและส่วนย่อยต่อไปนี้ **ไม่มีในชุดดีไซน์ Figma** โดยให้ยึดโครงสร้างและลำดับการใช้งานจาก `prototype/index.html` แล้วประกอบขึ้นจาก **Component กลาง (`app/lib/core/widgets/`)** ที่ใช้สไตล์และ Token เดียวกับ Figma (ไม่ต้อง export ภาพเพิ่ม):

1. **สต็อก — นับของเหลือปิดวัน (`StockCount`):** ตารางกรอกยอดคงเหลือแยกตามที่เก็บ (`ตู้เย็น` / `ตู้แช่แข็ง` / `ของแห้ง`) พร้อมแป้นตัวเลขพับได้ (`NumPad`)
2. **สต็อก — บันทึกซื้อของเข้า (`PurchaseModal`) และค่าใช้จ่ายรายวัน (`StockExpense` / `ExpenseModal`)**
3. **กะการขาย (`ShiftView` / `OpenShiftForm`):** หน้าเปิดกะ ระบุเงินทอนตั้งต้น และหน้าปิดกะ/กระทบยอดเงินสด
4. **ภาพรวมกำไร (`DashboardView`):** การ์ดสรุปตัวเลข (`Stat` 2 กลุ่ม), กราฟกำไรรายวัน (`ProfitChart`), และป้ายเตือนงานค้าง (`PendingBadge`)
5. **ตั้งค่าร้าน 13 หมวด (`SetupView`):** ข้อมูลร้าน, แพ็กเกจ, สินค้าเสริม, วัตถุดิบ, แหล่งซื้อ, โต๊ะ, พนักงาน/สิทธิ์, ช่องทางชำระ, สูตรกำไร (`CostingForm`), ค่าใช้จ่ายคงที่, ประเภทค่าใช้จ่าย, ธีม (`ThemeSettings`), และข้อมูลตัวอย่าง (ใช้ `CrudSection` + `FormFields` + `Modal`)
6. **ใบเสร็จและ Modal เฉพาะทาง (`Receipt`, `ReceiptModal`, `RemoveItemModal`)**
7. **Layout มือถือ (`≤760px`) และแนวนอนความสูงต่ำ (`≤520px`):** เมนูล่าง 4 รายการ + ปุ่ม "เพิ่มเติม" และแถบดูออเดอร์ด้านล่าง
