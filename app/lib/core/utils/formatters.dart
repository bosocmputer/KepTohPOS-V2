import 'package:app/domain/roles.dart';

const List<String> _thWeekdaysShort = <String>[
  'อา.',
  'จ.',
  'อ.',
  'พ.',
  'พฤ.',
  'ศ.',
  'ส.',
];

const List<String> _thMonthsShort = <String>[
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

const List<String> _thMonthsLong = <String>[
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

String _addCommas(String intPart) {
  final neg = intPart.startsWith('-');
  final digits = neg ? intPart.substring(1) : intPart;
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buf.write(',');
    }
    buf.write(digits[i]);
  }
  return neg ? '-$buf' : buf.toString();
}

/// Formats a number with thousand separators and fixed [decimals] (`fmt`).
String fmt(num? n, [int decimals = 0]) {
  if (n == null || n.isNaN) return '–';
  final fixed = n.toDouble().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intFormatted = _addCommas(parts[0]);
  return parts.length > 1 ? '$intFormatted.${parts[1]}' : intFormatted;
}

/// Formats a quantity with at most 2 decimal places (`fmtQ`).
String fmtQ(num? n) {
  if (n == null || n.isNaN) return '–';
  final rounded = r2(n);
  if (rounded == rounded.truncateToDouble()) {
    return fmt(rounded.toInt());
  }
  final s = fmt(rounded, 2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

/// Formats a live numeric input string with thousand separators while
/// preserving a trailing decimal point (e.g. `'1000.'` -> `'1,000.'`).
String fmtInputNum(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  final parts = s.split('.');
  final intPart = parts[0].isEmpty ? '0' : _addCommas(parts[0]);
  return parts.length > 1 ? '$intPart.${parts.sublist(1).join()}' : intPart;
}

/// Formats a [satang] amount in Thai Baht (`baht` in `prototype/index.html`).
String baht(num? satang, [int decimals = 0]) {
  if (satang == null || satang.isNaN) return '–';
  return '฿${fmt(satang / 100, decimals)}';
}

/// Formats a [satang] amount with thousand separators, without the currency
/// sign (tables and chart labels).
String fmtBaht(num? satang, [int decimals = 0]) =>
    fmt(satang == null ? null : satang / 100, decimals);

/// Formats [satang] as the plain baht text used in number inputs
/// (`199`, `199.50`).
String bahtInputText(int satang) => satang % 100 == 0
    ? (satang ~/ 100).toString()
    : (satang / 100).toStringAsFixed(2);

/// Formats a `YYYY-MM-DD` key as Thai short date (`thDate` in `index.html`).
String thDate(String key) {
  final d = parseKey(key);
  final wd = _thWeekdaysShort[d.weekday % 7];
  final m = _thMonthsShort[d.month - 1];
  final be2 = (d.year + 543) % 100;
  return '$wd ${d.day} $m ${padInt(be2)}';
}

/// Formats a `YYYY-MM-DD` key as short day + month (`thDateShort`).
String thDateShort(String key) {
  final d = parseKey(key);
  return '${d.day} ${_thMonthsShort[d.month - 1]}';
}

/// Formats a `YYYY-MM` key as full Thai month and Buddhist year (`thMonth`).
String thMonth(String ym) {
  final d = parseKey('$ym-01');
  return '${_thMonthsLong[d.month - 1]} ${d.year + 543}';
}

/// Formats an ISO-8601 timestamp as `HH:mm` local time (`thTime`).
String thTime(String iso) {
  final d = DateTime.parse(iso).toLocal();
  return '${padInt(d.hour)}:${padInt(d.minute)}';
}
