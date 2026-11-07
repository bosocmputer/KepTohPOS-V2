import 'package:app/domain/models.dart';
import 'package:app/domain/setup_ops.dart';

/// Validates and saves the store profile and VAT settings (`ShopForm`).
SetupCrudResult saveShopInState(PosState s, ShopConfig next) {
  if (next.name.trim().isEmpty) {
    return const SetupCrudResult.failure('กรุณากรอกชื่อร้าน');
  }
  if (next.vatRate < 0 || next.vatRate > 100) {
    return const SetupCrudResult.failure(
      'อัตราภาษีมูลค่าเพิ่มต้องอยู่ระหว่าง 0 ถึง 100%',
      guard: true,
    );
  }
  if (next.servicePct < 0 || next.servicePct > 100) {
    return const SetupCrudResult.failure(
      'อัตราค่าบริการต้องอยู่ระหว่าง 0 ถึง 100%',
      guard: true,
    );
  }
  if (next.defaultFloat < 0) {
    return const SetupCrudResult.failure(
      'เงินทอนตั้งต้นกะต้องไม่ติดลบ',
      guard: true,
    );
  }
  final cleanTax = next.taxId.replaceAll(RegExp(r'[\s-]'), '');
  if (cleanTax.isNotEmpty && !RegExp(r'^\d{13}$').hasMatch(cleanTax)) {
    return const SetupCrudResult.failure(
      'เลขประจำตัวผู้เสียภาษีต้องเป็นตัวเลข 13 หลัก',
      guard: true,
    );
  }
  s.shop = _keepingAppearance(s, next);
  return const SetupCrudResult.success('บันทึกข้อมูลร้านแล้ว');
}

/// Saves the profit and costing formulas (`CostingForm`).
SetupCrudResult saveCostingInState(PosState s, ShopConfig next) {
  s.shop = _keepingAppearance(s, next);
  return const SetupCrudResult.success('บันทึกสูตรคำนวณแล้ว');
}

ShopConfig _keepingAppearance(PosState s, ShopConfig next) => next.copyWith(
  themeMode: s.shop.themeMode,
  themePalette: s.shop.themePalette,
  bankAccounts: s.shop.bankAccounts,
);
