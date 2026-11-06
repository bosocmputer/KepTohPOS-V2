import 'package:app/domain/models.dart';
import 'package:app/domain/order_calc.dart';
import 'package:app/domain/roles.dart';
import 'package:app/domain/settle.dart';
import 'package:app/domain/setup_ops.dart';

export 'package:app/domain/dashboard_reports_ops.dart';
export 'package:app/domain/demo_sim_ops.dart';
export 'package:app/domain/ledger.dart';
export 'package:app/domain/models.dart';
export 'package:app/domain/order_calc.dart';
export 'package:app/domain/pos_repository.dart';
export 'package:app/domain/roles.dart';
export 'package:app/domain/seed.dart';
export 'package:app/domain/settle.dart';
export 'package:app/domain/setup_ops.dart';
export 'package:app/domain/stock_ops.dart';

/// Builds a [BillRecord] representing the POS Slip (`ใบแจ้งยอด` or settled
/// receipt) of an occupied table (`s.openTables[tableId]`), or `null` if the
/// table is not open.
BillRecord? buildTablePosSlip(
  PosState s,
  String tableId, {
  StaffMember? staff,
  DateTime? now,
}) {
  final o = s.openTables[tableId];
  final tb = s.tables.where((t) => t.id == tableId).firstOrNull;
  if (o == null || tb == null) return null;
  final due = tableDue(s, o);
  if (due == 0 && o.billIds.isNotEmpty) {
    for (final bid in o.billIds.reversed) {
      final b = s.sales.where((x) => x.id == bid && !x.voided).firstOrNull;
      if (b != null) return b;
    }
    final last = s.sales.where((x) => x.id == o.billIds.last).firstOrNull;
    if (last != null) return last;
  }
  final pkg = s.packages.where((p) => p.id == o.packageId).firstOrNull;
  final totals = o.timing == 'after'
      ? tableTotals(o)
      : TableTotals(a: o.heads.a, c: o.heads.c, f: o.heads.f);
  final order = orderOf(s, pkg, totals);
  final current = now ?? DateTime.now();
  return BillRecord(
    id: 'slip-${tb.id}',
    no: 'SLIP-${tb.name}',
    date: businessDayKey(current.toLocal(), s.shop.dayCutoffMinutes),
    at: o.openedAt,
    tableId: tb.id,
    tableName: tb.name,
    staffId: staff?.id ?? s.currentStaffId,
    staffName: staff?.name ?? '-',
    packageId: o.packageId,
    lines: order.lines,
    subtotal: order.subtotal,
    service: order.service,
    vat: order.vat,
    rounding: order.rounding,
    total: order.total,
    heads: order.heads.copy(),
    methodId: 'qr-slip',
    methodName: 'รอชำระเงิน (สแกน QR พร้อมเพย์)',
    methodType: 'qr',
    received: 0,
    change: 0,
    vatMode: s.shop.vatMode,
    vatRate: s.shop.vatRate,
    isSlipPreview: true,
  );
}

/// Cancels an unpaid open table (`openTables[tableId]`), restoring any addon
/// stock deducted by sent rounds, and returns the table to free status.
bool cancelOpenTable(PosState st, String tableId) {
  final o = st.openTables[tableId];
  if (o == null) return false;
  final totals = tableTotals(o);
  final returnMap = <String, int>{
    for (final e in totals.ad.entries)
      if (e.value > 0) e.key: -e.value,
  };
  if (returnMap.isNotEmpty) {
    takeStock(st, returnMap);
  }
  st.openTables.remove(tableId);
  return true;
}

/// Validates and upserts a [BankAccountItem] in `s.shop.bankAccounts`.
SetupCrudResult upsertBankAccountInState(PosState s, BankAccountItem item) {
  if (item.bankName.trim().isEmpty) {
    return const SetupCrudResult.failure('กรุณากรอกชื่อธนาคาร');
  }
  if (item.accountNo.trim().isEmpty) {
    return const SetupCrudResult.failure('กรุณากรอกเลขที่บัญชี');
  }
  final accounts = List<BankAccountItem>.from(s.shop.bankAccounts);
  if (!item.active && !accounts.any((x) => x.id != item.id && x.active)) {
    return const SetupCrudResult.failure(
      'ต้องเปิดใช้งานบัญชีธนาคารสำหรับรับโอนอย่างน้อย 1 บัญชี',
      guard: true,
    );
  }
  final normalized = item.copyWith(
    bankName: item.bankName.trim(),
    accountNo: item.accountNo.trim(),
    accountName: item.accountName.trim(),
  );
  final idx = accounts.indexWhere((x) => x.id == normalized.id);
  idx >= 0 ? accounts[idx] = normalized : accounts.add(normalized);
  s.shop = s.shop.copyWith(bankAccounts: accounts);
  return const SetupCrudResult.success('บันทึกบัญชีธนาคารเรียบร้อย');
}
