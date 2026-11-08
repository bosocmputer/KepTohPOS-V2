import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Maps semantic icon keys (`ICONS` in `prototype/index.html` and Figma visual
/// components) to [HugeIcons] stroke-rounded [IconData].
///
/// All icons across the app must be resolved through [AppIcons] / [AppIcon].
abstract final class AppIcons {
  static const Map<String, IconData> byName = <String, IconData>{
    'tables': HugeIcons.strokeRoundedGridView,
    'table': HugeIcons.strokeRoundedRestaurantTable,
    'receipt': HugeIcons.strokeRoundedInvoice02,
    'bills': HugeIcons.strokeRoundedInvoice02,
    'box': HugeIcons.strokeRoundedPackage,
    'stock': HugeIcons.strokeRoundedPackage,
    'clock': HugeIcons.strokeRoundedClock01,
    'shift': HugeIcons.strokeRoundedClock01,
    'chart': HugeIcons.strokeRoundedChartColumn,
    'dashboard': HugeIcons.strokeRoundedChartColumn,
    'list': HugeIcons.strokeRoundedCheckList,
    'reports': HugeIcons.strokeRoundedCheckList,
    'gear': HugeIcons.strokeRoundedSettings01,
    'setup': HugeIcons.strokeRoundedSettings01,
    'user': HugeIcons.strokeRoundedUser,
    'plus': HugeIcons.strokeRoundedAdd01,
    'minus': HugeIcons.strokeRoundedRemove01,
    'x': HugeIcons.strokeRoundedCancel01,
    'trash': HugeIcons.strokeRoundedDelete02,
    'edit': HugeIcons.strokeRoundedNoteEdit,
    'note': HugeIcons.strokeRoundedNoteEdit,
    'copy': HugeIcons.strokeRoundedCopy01,
    'flame': HugeIcons.strokeRoundedFire,
    'printer': HugeIcons.strokeRoundedPrinter,
    'check': HugeIcons.strokeRoundedTick02,
    'sidebar': HugeIcons.strokeRoundedSidebarLeft,
    'logout': HugeIcons.strokeRoundedLogout03,
    'chevron': HugeIcons.strokeRoundedArrowDown01,
    'back': HugeIcons.strokeRoundedArrowLeft01,
    'forward': HugeIcons.strokeRoundedArrowRight01,
    'search': HugeIcons.strokeRoundedSearch01,
    'backspace': Icons.backspace_outlined,
    'menu': HugeIcons.strokeRoundedMenu01,
    'package': HugeIcons.strokeRoundedRestaurant01,
    'buffet': HugeIcons.strokeRoundedRestaurant01,
    'cup': HugeIcons.strokeRoundedSoftDrink01,
    'drink': HugeIcons.strokeRoundedSoftDrink01,
    'coffee': HugeIcons.strokeRoundedCoffee01,
    'meat': HugeIcons.strokeRoundedSteak,
    'veg': HugeIcons.strokeRoundedBroccoli,
    'plate': HugeIcons.strokeRoundedDish01,
    'snack': HugeIcons.strokeRoundedDish01,
    'noodles': HugeIcons.strokeRoundedNoodles,
    'ice': HugeIcons.strokeRoundedIceCream01,
    'cash': HugeIcons.strokeRoundedCash01,
    'qr': HugeIcons.strokeRoundedQrCode,
    'transfer': HugeIcons.strokeRoundedBank,
    'card': HugeIcons.strokeRoundedCreditCardPos,
    'filter': HugeIcons.strokeRoundedFilterHorizontal,
    'grid': HugeIcons.strokeRoundedGridView,
    'cloud-done': HugeIcons.strokeRoundedCloudSavingDone01,
    'cloud-upload': HugeIcons.strokeRoundedCloudUpload,
    'wifi-off': HugeIcons.strokeRoundedWifiOff01,
    'sun': HugeIcons.strokeRoundedSun03,
    'moon': HugeIcons.strokeRoundedMoon02,
    'alert': HugeIcons.strokeRoundedAlertCircle,
  };

  static IconData resolve(String name) =>
      byName[name] ?? HugeIcons.strokeRoundedCircle;

  /// Resolves a semantic icon key for a product/addon category.
  static String forCategory(String? category) {
    final c = (category ?? '').trim();
    if (c.contains('เครื่องดื่ม') || c.contains('น้ำ')) return 'drink';
    if (c.contains('เนื้อ') || c.contains('หมู') || c.contains('ทะเล')) {
      return 'meat';
    }
    if (c.contains('ผัก')) return 'veg';
    if (c.contains('ของหวาน') || c.contains('ไอศกรีม')) return 'ice';
    if (c.contains('แพ็กเกจ') || c.contains('บุฟเฟต์')) return 'package';
    if (c.contains('ของทานเล่น') || c.contains('อาหาร')) return 'plate';
    return 'plate';
  }

  /// Resolves a semantic icon key for a payment method type (`cash`/`qr`/`transfer`).
  static String forPaymentType(String type) => switch (type) {
    'cash' => 'cash',
    'qr' => 'qr',
    'card' => 'card',
    _ => 'transfer',
  };

  /// Resolves a semantic icon key for an order/sent line (`head` -> `'user'`,
  /// `pkg`/`buffet` -> `'package'`, `addon` -> [forCategory]).
  static String forLineKind(String kind, {String? addonCategory}) =>
      switch (kind) {
        'head' => 'user',
        'pkg' || 'buffet' => 'package',
        _ => forCategory(addonCategory ?? 'เครื่องดื่ม'),
      };
}

/// Shared icon component (`Icon` in `prototype/index.html`).
class AppIcon extends StatelessWidget {
  const new(
    this.name, {
    super.key,
    this.size = AppDimensions.iconMd,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
    AppIcons.resolve(name),
    size: size,
    color: color ?? IconTheme.of(context).color ?? context.tokens.ink,
  );
}
