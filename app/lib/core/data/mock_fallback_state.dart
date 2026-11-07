import 'package:app/domain/domain.dart';

/// Minimal state for widget tests that do not load the mock assets.
PosState buildFallbackState(DateTime currentNow) {
  return PosState(
    startDate: '2026-10-05',
    shop: const ShopConfig(
      name: 'จ่าโบ้หมูกะทะ',
      address:
          '95/7 Faham , Muang Chiang Mai, Chiang Mai, Thailand, Chiang Mai',
      phone: '082 929 5566',
      promptpay: '0829295566',
    ),
    packages: const <PackageItem>[
      PackageItem(
        id: 'pk1',
        name: 'บุฟเฟต์หมู',
        adultPrice: 19900,
        childPrice: 9900,
      ),
      PackageItem(
        id: 'pk2',
        name: 'หมู + ทะเล',
        adultPrice: 27900,
        childPrice: 13900,
        timeLimit: 120,
      ),
    ],
    addons: <AddonItem>[
      AddonItem(
        id: 'ad1',
        name: 'น้ำเปล่า',
        category: 'เครื่องดื่ม',
        price: 1500,
        cost: 600,
        stock: 96,
      ),
    ],
    suppliers: const <SupplierItem>[SupplierItem(id: 'sup1', name: 'ตลาดสด')],
    ingredients: const <IngredientItem>[],
    tables: const <DiningTable>[
      DiningTable(id: 't1', name: 'A1', seats: 4, zone: 'ในร้าน'),
    ],
    staff: const <StaffMember>[
      StaffMember(id: 'st1', name: 'อัย', role: 'owner', pin: '1234'),
      StaffMember(id: 'st2', name: 'ไอติม', role: 'manager', pin: '2222'),
      StaffMember(id: 'st3', name: 'เนส', role: 'cashier', pin: '1111'),
    ],
    payments: const <PaymentMethod>[
      PaymentMethod(id: 'pm1', name: 'เงินสด', type: 'cash'),
      PaymentMethod(id: 'pm2', name: 'QR พร้อมเพย์', type: 'qr'),
      PaymentMethod(id: 'pm3', name: 'โอนเงิน', type: 'transfer'),
    ],
    expenseTypes: const <ExpenseType>[ExpenseType(id: 'et1', name: 'แก๊ส')],
    fixedCosts: const <FixedCostItem>[],
    shifts: <ShiftRecord>[
      ShiftRecord(
        id: 'sh1',
        staffId: 'st3',
        openedAt: currentNow
            .subtract(const Duration(hours: 3))
            .toUtc()
            .toIso8601String(),
        floatAmount: 100000,
      ),
    ],
  );
}
