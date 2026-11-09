import 'package:app/domain/domain.dart';

/// In-memory sales-tax report computed from `state.sales`.
mixin MockPosTaxReport implements PosRepository {
  static const String _device = 'M1';

  @override
  Future<List<SalesTaxRow>> getSalesTaxReport(String month) async {
    final byId = <String, BillRecord>{for (final b in state.sales) b.id: b};
    final bills =
        state.sales
            .where((b) => !b.isSlipPreview && b.date.startsWith(month))
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    return [
      for (final b in bills)
        SalesTaxRow(
          businessDate: b.date,
          at: b.at,
          no: b.no,
          docType: b.isFullInvoice
              ? 'full'
              : (b.isTaxInvoice ? 'abb' : 'receipt'),
          deviceCode: _device,
          rdMachineCode: b.rdMachineCode,
          buyerName: b.buyerName,
          buyerTaxId: b.buyerTaxId,
          buyerBranch: b.buyerBranch,
          base: b.total - b.vat,
          vat: b.vat,
          total: b.total,
          voided: b.voided,
          voidReason: b.voidReason,
          replacesNo: byId[b.replacesBillId]?.no,
        ),
    ];
  }

  @override
  Future<List<DeviceDaySummary>> getDailyDeviceSummary(
    String from,
    String to,
  ) async {
    final groups = <String, List<BillRecord>>{};
    for (final b in state.sales) {
      if (b.isSlipPreview || b.date.compareTo(from) < 0) continue;
      if (b.date.compareTo(to) > 0) continue;
      final dev = b.isFullInvoice ? 'FULL' : _device;
      (groups['${b.date}|$dev'] ??= <BillRecord>[]).add(b);
    }
    final keys = groups.keys.toList()..sort();
    return [
      for (final k in keys)
        _summary(
          k.split('|'),
          groups[k]!..sort((a, b) => a.at.compareTo(b.at)),
        ),
    ];
  }

  DeviceDaySummary _summary(List<String> key, List<BillRecord> g) {
    final live = g.where((b) => !b.voided);
    int sum(int Function(BillRecord) f) => live.fold(0, (a, b) => a + f(b));
    return DeviceDaySummary(
      businessDate: key[0],
      deviceCode: key[1],
      rdMachineCode: g.map((b) => b.rdMachineCode).nonNulls.firstOrNull,
      firstNo: g.first.no,
      lastNo: g.last.no,
      bills: live.length,
      voided: g.length - live.length,
      base: sum((b) => b.total - b.vat),
      vat: sum((b) => b.vat),
      total: sum((b) => b.total),
    );
  }
}
