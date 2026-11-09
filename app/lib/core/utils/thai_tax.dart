/// Strips spaces and dashes from a typed tax ID.
String normalizeTaxId(String raw) => raw.replaceAll(RegExp(r'[\s-]'), '');

/// True when [raw] normalizes to exactly 13 digits.
bool isValidTaxId(String raw) =>
    RegExp(r'^\d{13}$').hasMatch(normalizeTaxId(raw));

/// True when [code] is exactly 5 digits (`00000` = head office).
bool isValidBranchCode(String code) => RegExp(r'^\d{5}$').hasMatch(code);

/// `สำนักงานใหญ่` for `00000`, otherwise `สาขาที่ <code>`.
String branchLabel(String code) =>
    code == '00000' ? 'สำนักงานใหญ่' : 'สาขาที่ $code';

/// `YYYY-MM` keys of the last [count] months, newest first (includes [now]'s).
List<String> recentMonths(DateTime now, int count) =>
    List<String>.generate(count, (i) {
      final d = DateTime(now.year, now.month - i);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });

/// Last calendar day (28-31) of [year]/[month].
int lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;
