import 'package:app/domain/models.dart';
import 'package:app/domain/seed.dart';

int _setupSeq = 0;

/// Generates a deterministic-friendly unique ID for a new catalog item.
String nextSetupUid(String prefix, [DateTime? now]) {
  _setupSeq = (_setupSeq + 1) & 0xFFFFF;
  final ts = (now ?? DateTime.now()).millisecondsSinceEpoch.toRadixString(36);
  final tail = ts.length > 4 ? ts.substring(ts.length - 4) : ts;
  return '$prefix$tail${_setupSeq.toRadixString(36).padLeft(3, '0')}';
}

/// Result of a domain setup CRUD or validation operation.
class SetupCrudResult {
  const new({required this.ok, this.message = '', this.isGuardBlock = false});

  const new success([String msg = 'บันทึกเรียบร้อย'])
    : this(ok: true, message: msg);

  const new failure(String msg, {bool guard = false})
    : this(ok: false, message: msg, isGuardBlock: guard);

  final bool ok;
  final String message;
  final bool isGuardBlock;
}

/// Checks whether deleting [id] in [section] is blocked by relational state
/// (`guard` in `prototype/index.html:1703-1742`).
String? checkSetupDeleteGuard(
  PosState s, {
  required String section,
  required String id,
  String? currentStaffId,
}) {
  switch (section) {
    case 'packages':
      if (s.openTables.values.any((o) => o.packageId == id)) {
        return 'มีโต๊ะที่กำลังเปิดใช้แพ็กเกจนี้อยู่ ปิดโต๊ะก่อนลบ';
      }
    case 'suppliers':
      final used = s.ingredients
          .where((i) => i.supplierId == id)
          .map((i) => i.name)
          .toList();
      if (used.isNotEmpty) {
        return 'ยังมีวัตถุดิบที่ผูกกับแหล่งซื้อนี้อยู่ (${used.join(', ')})';
      }
    case 'tables':
      if (s.openTables.containsKey(id)) {
        return 'โต๊ะนี้กำลังเปิดอยู่ ปิดโต๊ะก่อนลบ';
      }
    case 'staff':
      if (id == (currentStaffId ?? s.currentStaffId)) {
        return 'ไม่สามารถลบตัวเองขณะเข้าใช้งานอยู่ได้';
      }
      final target = s.staff.where((x) => x.id == id).firstOrNull;
      final owners = s.staff.where((x) => x.active && x.role == 'owner').length;
      if (target != null &&
          target.role == 'owner' &&
          target.active &&
          owners <= 1) {
        return 'ต้องเหลือเจ้าของร้านที่ใช้งานอยู่อย่างน้อย 1 คน';
      }
    case 'payments':
      final target = s.payments.where((x) => x.id == id).firstOrNull;
      final activeCount = s.payments.where((x) => x.active).length;
      if (target != null && target.active && activeCount <= 1) {
        return 'ต้องมีช่องทางชำระเงินที่เปิดใช้งานอย่างน้อย 1 ช่องทาง';
      }
    case 'bankAccounts':
      if (s.sales.any((b) => b.bankAccountId == id)) {
        return 'บัญชีธนาคารนี้มีประวัติรับชำระเงินแล้ว กรุณาปิดใช้งานแทนการลบ';
      }
      final target = s.shop.bankAccounts.where((x) => x.id == id).firstOrNull;
      if (target != null &&
          target.active &&
          s.shop.activeBankAccounts.length <= 1) {
        return 'ต้องมีบัญชีธนาคารที่เปิดใช้งานอย่างน้อย 1 บัญชี';
      }
    case 'expenseTypes':
      if (s.expenses.any((e) => e.typeId == id)) {
        return 'มีรายการค่าใช้จ่ายที่ใช้ประเภทนี้อยู่';
      }
  }
  return null;
}

void _upsertById<T>(List<T> list, T item, String Function(T) idOf) {
  final idx = list.indexWhere((x) => idOf(x) == idOf(item));
  idx >= 0 ? list[idx] = item : list.add(item);
}

SetupCrudResult _fail(String msg, [bool guard = false]) =>
    SetupCrudResult.failure(msg, guard: guard);

SetupCrudResult _ok(String msg) => SetupCrudResult.success(msg);

/// Validates and upserts a [PackageItem].
SetupCrudResult upsertPackageInState(PosState s, PackageItem item) {
  if (item.name.trim().isEmpty) return _fail('กรุณากรอกชื่อแพ็กเกจ');
  if (item.adultPrice < 0 || item.childPrice < 0 || item.timeLimit < 0) {
    return _fail('ราคาและเวลาจำกัดต้องไม่ติดลบ');
  }
  _upsertById(s.packages, item, (x) => x.id);
  return _ok('บันทึกแพ็กเกจเรียบร้อย');
}

/// Validates and upserts an [AddonItem].
SetupCrudResult upsertAddonInState(PosState s, AddonItem item) {
  if (item.name.trim().isEmpty) return _fail('กรุณากรอกชื่อสินค้า');
  if (item.price < 0 || item.cost < 0 || item.stock < 0) {
    return _fail('ราคา ต้นทุน และจำนวนคงเหลือต้องไม่ติดลบ');
  }
  final cat = item.category.trim().isEmpty ? 'เครื่องดื่ม' : item.category;
  _upsertById(s.addons, item.copyWith(category: cat), (x) => x.id);
  return _ok('บันทึกสินค้าขายเสริมเรียบร้อย');
}

/// Validates and upserts an [IngredientItem].
SetupCrudResult upsertIngredientInState(PosState s, IngredientItem item) {
  if (item.name.trim().isEmpty) return _fail('กรุณากรอกชื่อวัตถุดิบ');
  if (item.lastCost < 0 || item.par < 0) {
    return _fail('ราคาต้นทุนและเกณฑ์ขั้นต่ำต้องไม่ติดลบ');
  }
  _upsertById(s.ingredients, item, (x) => x.id);
  return _ok('บันทึกวัตถุดิบเรียบร้อย');
}

/// Validates and upserts a [SupplierItem].
SetupCrudResult upsertSupplierInState(PosState s, SupplierItem item) {
  if (item.name.trim().isEmpty) return _fail('กรุณากรอกชื่อแหล่งซื้อ');
  _upsertById(s.suppliers, item, (x) => x.id);
  return _ok('บันทึกแหล่งซื้อเรียบร้อย');
}

/// Validates and upserts a [DiningTable].
SetupCrudResult upsertTableInState(PosState s, DiningTable item) {
  final name = item.name.trim();
  if (name.isEmpty) return _fail('กรุณากรอกชื่อโต๊ะ');
  if (s.tables.any(
    (x) => x.id != item.id && x.name.trim().toLowerCase() == name.toLowerCase(),
  )) {
    return _fail('ชื่อโต๊ะนี้มีอยู่ในระบบแล้ว');
  }
  final normalized = item.copyWith(
    name: name,
    zone: item.zone.trim().isEmpty ? 'ในร้าน' : item.zone.trim(),
    seats: item.seats <= 0 ? 4 : item.seats,
  );
  _upsertById(s.tables, normalized, (x) => x.id);
  return _ok('บันทึกโต๊ะเรียบร้อย');
}

/// Validates and upserts a [StaffMember] with PIN and active-owner guards.
SetupCrudResult upsertStaffInState(
  PosState s,
  StaffMember item, {
  String? actorRole,
}) {
  if (actorRole != null && actorRole != 'owner') {
    return _fail('เฉพาะเจ้าของร้านเท่านั้นที่จัดการพนักงานได้', true);
  }
  if (item.name.trim().isEmpty) return _fail('กรุณากรอกชื่อพนักงาน');
  if (!RegExp(r'^\d{4}$').hasMatch(item.pin)) {
    return _fail('รหัส PIN ต้องเป็นตัวเลข 4 หลัก');
  }
  if (s.staff.any((x) => x.id != item.id && x.pin == item.pin)) {
    return _fail('รหัส PIN นี้ซ้ำกับพนักงานคนอื่น');
  }
  final existing = s.staff.where((x) => x.id == item.id).firstOrNull;
  if (existing != null &&
      existing.role == 'owner' &&
      existing.active &&
      (!item.active || item.role != 'owner')) {
    final otherOwners = s.staff
        .where((x) => x.id != item.id && x.active && x.role == 'owner')
        .length;
    if (otherOwners == 0) {
      return _fail('ต้องเหลือเจ้าของร้านที่ใช้งานอยู่อย่างน้อย 1 คน', true);
    }
  }
  _upsertById(s.staff, item, (x) => x.id);
  return _ok('บันทึกข้อมูลพนักงานเรียบร้อย');
}

/// Validates and upserts a [PaymentMethod].
SetupCrudResult upsertPaymentInState(PosState s, PaymentMethod item) {
  if (item.name.trim().isEmpty) return _fail('กรุณากรอกชื่อช่องทางชำระเงิน');
  if (!item.active && !s.payments.any((x) => x.id != item.id && x.active)) {
    return _fail('ต้องเปิดใช้งานช่องทางชำระเงินอย่างน้อย 1 ช่องทาง', true);
  }
  _upsertById(s.payments, item, (x) => x.id);
  return _ok('บันทึกช่องทางชำระเงินเรียบร้อย');
}

/// Validates and upserts a [FixedCostItem].
SetupCrudResult upsertFixedCostInState(PosState s, FixedCostItem item) {
  if (item.name.trim().isEmpty) return _fail('กรุณากรอกรายการค่าใช้จ่ายคงที่');
  if (item.amount < 0) return _fail('ยอดค่าใช้จ่ายต้องไม่ติดลบ');
  _upsertById(s.fixedCosts, item, (x) => x.id);
  return _ok('บันทึกค่าใช้จ่ายคงที่เรียบร้อย');
}

/// Validates and upserts an [ExpenseType].
SetupCrudResult upsertExpenseTypeInState(PosState s, ExpenseType item) {
  if (item.name.trim().isEmpty) return _fail('กรุณากรอกชื่อประเภทค่าใช้จ่าย');
  _upsertById(s.expenseTypes, item, (x) => x.id);
  return _ok('บันทึกประเภทค่าใช้จ่ายเรียบร้อย');
}

/// Deletes an item by [id] from [section] after checking relational guards.
SetupCrudResult deleteFromSetupSection(
  PosState s, {
  required String section,
  required String id,
  String? currentStaffId,
}) {
  final guard = checkSetupDeleteGuard(
    s,
    section: section,
    id: id,
    currentStaffId: currentStaffId,
  );
  if (guard != null) return _fail(guard, true);
  switch (section) {
    case 'packages':
      s.packages.removeWhere((x) => x.id == id);
    case 'addons':
      s.addons.removeWhere((x) => x.id == id);
    case 'ingredients':
      s.ingredients.removeWhere((x) => x.id == id);
    case 'suppliers':
      s.suppliers.removeWhere((x) => x.id == id);
    case 'tables':
      s.tables.removeWhere((x) => x.id == id);
    case 'staff':
      s.staff.removeWhere((x) => x.id == id);
    case 'payments':
      s.payments.removeWhere((x) => x.id == id);
    case 'bankAccounts':
      s.shop = s.shop.copyWith(
        bankAccounts: s.shop.bankAccounts.where((x) => x.id != id).toList(),
      );
    case 'fixedCosts':
      s.fixedCosts.removeWhere((x) => x.id == id);
    case 'expenseTypes':
      s.expenseTypes.removeWhere((x) => x.id == id);
    default:
      return _fail('ไม่รู้จักหมวดข้อมูล');
  }
  return _ok('ลบรายการเรียบร้อย');
}

void _resetMap<K, V>(Map<K, V> dst, Map<K, V> src) => dst
  ..clear()
  ..addAll(src);

void _resetList<T>(List<T> dst, List<T> src) => dst
  ..clear()
  ..addAll(src);

/// Resets 30-day transactional demo data while keeping master catalogs intact.
void resetDemoTransactionsInState(PosState s, {DateTime? now}) {
  final fresh = seed(
    shop: s.shop,
    packages: s.packages,
    addons: s.addons,
    suppliers: s.suppliers,
    ingredients: s.ingredients,
    tables: s.tables,
    staff: s.staff,
    payments: s.payments,
    expenseTypes: s.expenseTypes,
    fixedCosts: s.fixedCosts,
    now: now,
  );
  s.startDate = fresh.startDate;
  _resetMap(s.seq, fresh.seq);
  _resetMap(s.openTables, fresh.openTables);
  _resetList(s.shifts, fresh.shifts);
  _resetList(s.sales, fresh.sales);
  _resetList(s.purchases, fresh.purchases);
  _resetMap(s.counts, fresh.counts);
  _resetMap(s.initialStock, fresh.initialStock);
  _resetList(s.expenses, fresh.expenses);
}
