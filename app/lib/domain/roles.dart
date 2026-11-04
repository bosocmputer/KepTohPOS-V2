/// Role labels (`ROLE` in `prototype/index.html`).
const Map<String, String> kRoles = <String, String>{
  'owner': 'เจ้าของร้าน',
  'manager': 'ผู้จัดการ',
  'cashier': 'แคชเชียร์',
};

/// Payment type labels (`PAY_TYPE` in `prototype/index.html`).
const Map<String, String> kPayTypes = <String, String>{
  'cash': 'เงินสด',
  'qr': 'QR พร้อมเพย์',
  'transfer': 'โอนเงิน',
  'card': 'บัตร',
};

/// VAT modes (`VAT_MODE` in `prototype/index.html`).
const Map<String, String> kVatModes = <String, String>{
  'none': 'ไม่จด VAT',
  'included': 'ราคารวม VAT 7% แล้ว',
  'excluded': 'บวก VAT 7% เพิ่ม',
};

/// Ingredient storage locations (`LOCATION` in `prototype/index.html`).
const Map<String, String> kLocations = <String, String>{
  'fridge': 'ตู้เย็น',
  'freezer': 'ตู้แช่แข็ง',
  'dry': 'ชั้นแห้ง / ห้องเก็บของ',
};

/// Stock counting frequencies (`COUNT_FREQ` in `prototype/index.html`).
const Map<String, String> kCountFreqs = <String, String>{
  'daily': 'นับทุกวัน',
  'weekly': 'นับสัปดาห์ละครั้ง',
};

/// Ingredient cost methods (`COST_METHOD` in `prototype/index.html`).
const Map<String, String> kCostMethods = <String, String>{
  'avg': 'ต้นทุนเฉลี่ยถ่วงน้ำหนัก',
  'last': 'ราคาซื้อล่าสุด',
};

/// Bill rounding modes (`ROUNDING` in `prototype/index.html`).
const Map<String, String> kRoundingModes = <String, String>{
  'down': 'ปัดสตางค์ลงเป็นบาทเต็ม',
  'none': 'ไม่ปัดเศษ',
};

/// Payment timing modes (`PAY_TIMING` in `prototype/index.html`).
const Map<String, String> kPayTimings = <String, String>{
  'before': 'จ่ายก่อนกิน',
  'after': 'กินก่อนจ่าย',
};

/// Thai day-of-week names (`DOW` in `prototype/index.html`, 0 = Sunday).
const List<String> kDowNames = <String>[
  'อาทิตย์',
  'จันทร์',
  'อังคาร',
  'พุธ',
  'พฤหัสบดี',
  'ศุกร์',
  'เสาร์',
];

/// Discrete counting units (`COUNT_UNITS` in `prototype/index.html`).
const List<String> kCountUnits = <String>['ฟอง', 'แพ็ค', 'ถุง', 'ชิ้น', 'ขวด'];

/// Navigation item specification (`VIEWS` in `prototype/index.html`).
class AppViewSpec {
  const new({
    required this.id,
    required this.label,
    required this.icon,
    required this.title,
    this.roles,
  });

  final String id;
  final String label;
  final String icon;
  final String title;
  final List<String>? roles;
}

/// Main navigation items and role restrictions (`VIEWS` in `index.html`).
const List<AppViewSpec> kAppViews = <AppViewSpec>[
  AppViewSpec(
    id: 'tables',
    label: 'โต๊ะ',
    icon: 'tables',
    title: 'โต๊ะและการขาย',
  ),
  AppViewSpec(id: 'bills', label: 'บิล', icon: 'receipt', title: 'บิลขาย'),
  AppViewSpec(id: 'stock', label: 'สต็อก', icon: 'box', title: 'สต็อกวัตถุดิบ'),
  AppViewSpec(id: 'shift', label: 'กะ', icon: 'clock', title: 'กะการขาย'),
  AppViewSpec(
    id: 'dashboard',
    label: 'ภาพรวม',
    icon: 'chart',
    title: 'ภาพรวมกำไร',
    roles: <String>['owner', 'manager'],
  ),
  AppViewSpec(
    id: 'reports',
    label: 'รายงาน',
    icon: 'list',
    title: 'รายงานรายวัน',
    roles: <String>['owner', 'manager'],
  ),
  AppViewSpec(
    id: 'setup',
    label: 'ตั้งค่า',
    icon: 'gear',
    title: 'ตั้งค่าร้าน',
    roles: <String>['owner', 'manager'],
  ),
];

/// Checks whether a staff [role] can access [view].
bool canRoleAccessView(String role, AppViewSpec view) =>
    view.roles == null || view.roles!.contains(role);

/// Checks whether a staff [role] can access a view by [viewId] (or path).
bool canAccessViewId(String role, String viewId) {
  final base = viewId.split('/').first;
  for (final v in kAppViews) {
    if (v.id == base) return canRoleAccessView(role, v);
  }
  return false;
}

/// Returns all [AppViewSpec] entries accessible to [role].
List<AppViewSpec> allowedViewsForRole(String role) =>
    kAppViews.where((v) => canRoleAccessView(role, v)).toList();

/// Zero-pads [n] to length [l].
String padInt(int n, [int l = 2]) => n.toString().padLeft(l, '0');

/// Formats a [DateTime] as `YYYY-MM-DD` (`dkey` in `prototype/index.html`).
String dkey(DateTime d) => '${d.year}-${padInt(d.month)}-${padInt(d.day)}';

/// Parses a `YYYY-MM-DD` key into a local [DateTime] at midnight.
DateTime parseKey(String k) {
  final parts = k.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

/// Adds [days] calendar days to [d] (`addDays` in `prototype/index.html`).
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Rounds [n] to 2 decimal places using JS `Math.round(n * 100) / 100`
/// semantics (`Math.floor(x + 0.5)`).
double r2(num n) {
  final v = (n.toDouble() * 100 + 0.5).floorToDouble() / 100;
  return v == 0 ? 0 : v;
}

/// Rounds [n] according to [unit] (`roundQty` in `prototype/index.html`).
double roundQty(num n, String unit) {
  final d = n.toDouble();
  if (kCountUnits.contains(unit)) {
    final v = (d + 0.5).floorToDouble();
    return v == 0 ? 0 : v;
  }
  final v = (d * 10 + 0.5).floorToDouble() / 10;
  return v == 0 ? 0 : v;
}

/// Computes CRC-16/CCITT-FALSE for EMVCo PromptPay QR (`crc16` in JS).
String crc16(String s) {
  var c = 0xFFFF;
  for (var i = 0; i < s.length; i++) {
    c ^= s.codeUnitAt(i) << 8;
    for (var j = 0; j < 8; j++) {
      c = (c & 0x8000) != 0 ? ((c << 1) ^ 0x1021) & 0xFFFF : (c << 1) & 0xFFFF;
    }
  }
  return c.toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// Builds EMVCo PromptPay payload (`promptPayPayload` in `index.html`).
String promptPayPayload(String id, [num? amount]) {
  String t(String tag, String v) => '$tag${padInt(v.length)}$v';
  final digits = id.replaceAll(RegExp(r'\D'), '');
  final String acc;
  if (digits.length >= 13) {
    acc = t('02', digits);
  } else {
    final normalized =
        '0000000000000${digits.replaceFirst(RegExp('^0'), '66')}';
    acc = t('01', normalized.substring(normalized.length - 13));
  }
  final hasAmount = amount != null && amount > 0;
  final amtPart = hasAmount
      ? t('54', amount.toDouble().toStringAsFixed(2))
      : '';
  final p =
      '${t('00', '01')}${t('01', hasAmount ? '12' : '11')}'
      '${t('29', '${t('00', 'A000000677010111')}$acc')}'
      '${t('53', '764')}$amtPart${t('58', 'TH')}6304';
  return '$p${crc16(p)}';
}
