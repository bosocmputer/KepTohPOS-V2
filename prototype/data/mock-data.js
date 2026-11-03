/* =====================================================================
   KepToh POS — Mock data (JSON ล้วน) · แก้ตัวเลข/ชื่อร้านที่ไฟล์นี้ได้เลย
   - ไม่ใช้ไฟล์ .json ตรงๆ เพราะเปิด index.html แบบดับเบิลคลิก (file://) แล้วเบราว์เซอร์อ่าน .json ไม่ได้
   - ข้อมูลที่นี่คือ "ฐาน" ของร้านสมมติ ส่วนยอดขาย/ซื้อของย้อนหลัง 30 วัน
     index.html สร้างจากฐานนี้ทุกครั้งที่รีเซ็ต (เพื่อให้วันที่อิงวันนี้เสมอ)
   - ราคา/ปริมาณทั้งหมดเป็นข้อมูลจำลองสำหรับทดสอบ ไม่ใช่ตัวเลขจริงของร้าน
   ===================================================================== */
window.KEPTOH_MOCK = {
  "currentStaffId": "st1",
  "shop": {
    "name": "หมูกระทะลุงหมี",
    "branch": "ร้านตัวอย่าง",
    "address": "99/9 ถ.มิตรภาพ ต.ในเมือง อ.เมือง จ.ขอนแก่น 40000",
    "phone": "043-000-000",
    "taxId": "",
    "promptpay": "0812345678",
    "vatMode": "none",
    "servicePct": 0,
    "defaultFloat": 1000,
    "receiptFooter": "ขอบคุณที่อุดหนุน ทานให้อร่อย ไม่เหลือทิ้งนะคะ",
    "useTimer": true
  },
  "packages": [
    {"id":"pk1","name":"บุฟเฟต์หมูกระทะ","adultPrice":199,"childPrice":99,"childRule":"เด็กสูง 100–130 ซม.","freeRule":"ต่ำกว่า 100 ซม. ทานฟรี","timeLimit":0,"active":true},
    {"id":"pk2","name":"หมูกระทะ + ทะเล","adultPrice":279,"childPrice":139,"childRule":"เด็กสูง 100–130 ซม.","freeRule":"ต่ำกว่า 100 ซม. ทานฟรี","timeLimit":120,"active":true}
  ],
  "addons": [
    {"id":"ad1","name":"น้ำเปล่า 600 มล.","price":15,"cost":6,"stock":96,"active":true},
    {"id":"ad2","name":"น้ำแข็งถัง","price":20,"cost":6,"stock":999,"active":true},
    {"id":"ad3","name":"โค้ก 325 มล.","price":25,"cost":13,"stock":72,"active":true},
    {"id":"ad4","name":"โซดา","price":20,"cost":9,"stock":48,"active":true},
    {"id":"ad5","name":"เบียร์ช้าง ขวดใหญ่","price":80,"cost":56,"stock":60,"active":true},
    {"id":"ad6","name":"เบียร์ลีโอ ขวดใหญ่","price":80,"cost":55,"stock":60,"active":true},
    {"id":"ad7","name":"เบียร์สิงห์ ขวดใหญ่","price":90,"cost":63,"stock":36,"active":true}
  ],
  "suppliers": [
    {"id":"s1","name":"แม็คโคร สาขาขอนแก่น","phone":"","note":"ซื้อเนื้อสัตว์แช่แข็ง ซีฟู้ด ของแห้ง"},
    {"id":"s2","name":"เขียงหมูเจ๊ติ๋ม (ตลาดสด)","phone":"089-000-0001","note":"หมูหมัก ไก่ ตับ มันหมู"},
    {"id":"s3","name":"แผงผักป้าแดง (ตลาดสด)","phone":"089-000-0002","note":"ผัก เห็ด ไข่"},
    {"id":"s4","name":"ร้านถ่านลุงชัย","phone":"089-000-0003","note":"ส่งถึงร้าน"}
  ],
  "ingredients": [
    {"id":"i1","name":"หมูสามชั้นสไลซ์","unit":"กก.","lastCost":185,"par":14,"supplierId":"s1","category":"วัตถุดิบ","use":0.11},
    {"id":"i2","name":"สันคอหมูสไลซ์","unit":"กก.","lastCost":170,"par":8,"supplierId":"s1","category":"วัตถุดิบ","use":0.06},
    {"id":"i3","name":"หมูหมักนุ่ม","unit":"กก.","lastCost":150,"par":9,"supplierId":"s2","category":"วัตถุดิบ","use":0.07},
    {"id":"i4","name":"ไก่หมัก","unit":"กก.","lastCost":85,"par":6,"supplierId":"s2","category":"วัตถุดิบ","use":0.05},
    {"id":"i5","name":"ตับหมู","unit":"กก.","lastCost":90,"par":2,"supplierId":"s2","category":"วัตถุดิบ","use":0.015},
    {"id":"i6","name":"กุ้งขาว","unit":"กก.","lastCost":220,"par":4,"supplierId":"s1","category":"วัตถุดิบ","use":0.03},
    {"id":"i7","name":"ปลาหมึก","unit":"กก.","lastCost":180,"par":3,"supplierId":"s1","category":"วัตถุดิบ","use":0.025},
    {"id":"i8","name":"ลูกชิ้นรวม","unit":"กก.","lastCost":95,"par":5,"supplierId":"s1","category":"วัตถุดิบ","use":0.04},
    {"id":"i9","name":"ผักรวม (กาด/บุ้ง/กะหล่ำ)","unit":"กก.","lastCost":35,"par":12,"supplierId":"s3","category":"วัตถุดิบ","use":0.09},
    {"id":"i10","name":"เห็ดเข็มทอง","unit":"แพ็ค","lastCost":10,"par":10,"supplierId":"s3","category":"วัตถุดิบ","use":0.06},
    {"id":"i11","name":"วุ้นเส้น","unit":"กก.","lastCost":60,"par":2,"supplierId":"s1","category":"วัตถุดิบ","use":0.012},
    {"id":"i12","name":"ไข่ไก่","unit":"ฟอง","lastCost":3.8,"par":60,"supplierId":"s3","category":"วัตถุดิบ","use":0.3},
    {"id":"i13","name":"น้ำจิ้มสุกี้ (ทำเอง)","unit":"ลิตร","lastCost":70,"par":4,"supplierId":"s1","category":"วัตถุดิบ","use":0.03},
    {"id":"i14","name":"มันหมูทาเตา","unit":"กก.","lastCost":40,"par":1.5,"supplierId":"s2","category":"วัตถุดิบ","use":0.01},
    {"id":"i15","name":"ถ่าน","unit":"กก.","lastCost":18,"par":30,"supplierId":"s4","category":"วัสดุสิ้นเปลือง","use":0.25}
  ],
  "tables": [
    {"id":"t1","name":"A1","seats":4,"zone":"ในร้าน"},
    {"id":"t2","name":"A2","seats":4,"zone":"ในร้าน"},
    {"id":"t3","name":"A3","seats":4,"zone":"ในร้าน"},
    {"id":"t4","name":"A4","seats":4,"zone":"ในร้าน"},
    {"id":"t5","name":"A5","seats":4,"zone":"ในร้าน"},
    {"id":"t6","name":"A6","seats":4,"zone":"ในร้าน"},
    {"id":"t7","name":"A7","seats":4,"zone":"ในร้าน"},
    {"id":"t8","name":"A8","seats":4,"zone":"ในร้าน"},
    {"id":"t9","name":"B1","seats":6,"zone":"ลานด้านนอก"},
    {"id":"t10","name":"B2","seats":6,"zone":"ลานด้านนอก"},
    {"id":"t11","name":"B3","seats":6,"zone":"ลานด้านนอก"},
    {"id":"t12","name":"B4","seats":6,"zone":"ลานด้านนอก"}
  ],
  "staff": [
    {"id":"st1","name":"คุณแอน","role":"owner","pin":"1234","active":true},
    {"id":"st2","name":"คุณบี","role":"manager","pin":"2222","active":true},
    {"id":"st3","name":"น้องมุก","role":"cashier","pin":"1111","active":true},
    {"id":"st4","name":"น้องเต้","role":"cashier","pin":"3333","active":true}
  ],
  "payments": [
    {"id":"pm1","name":"เงินสด","type":"cash","active":true},
    {"id":"pm2","name":"พร้อมเพย์ (QR)","type":"qr","active":true},
    {"id":"pm3","name":"โอนเข้าบัญชีร้าน","type":"transfer","active":true},
    {"id":"pm4","name":"บัตรเครดิต","type":"card","active":false}
  ]
};
