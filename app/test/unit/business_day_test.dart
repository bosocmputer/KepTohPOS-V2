import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('B1: Business-day cutoff (businessDayKey & after-midnight sales)', () {
    test('businessDayKey shifts times before cutoff to previous day', () {
      expect(businessDayKey(DateTime(2026, 11, 7, 0, 30), 300), '2026-11-06');
      expect(businessDayKey(DateTime(2026, 11, 7, 4, 59), 300), '2026-11-06');
      expect(businessDayKey(DateTime(2026, 11, 7, 5), 300), '2026-11-07');
      expect(businessDayKey(DateTime(2026, 11, 7, 0, 30)), '2026-11-07');
    });

    test('settle at 23:50 and 00:30 with 05:00 cutoff groups both bills '
        'under the same business day in seq and computeLedger', () {
      final repo = MockPosRepository.createFallback(
        now: DateTime(2026, 11, 6, 18),
      );
      final s = repo.state.copy()
        ..startDate = '2026-11-06'
        ..shop = repo.state.shop.copyWith(dayCutoffMinutes: 300);
      final t1 = s.tables.first;
      final staff = s.staff.first;
      final pmCash = s.payments.first;

      // Bill 1 at 23:50 on Nov 6
      settle(
        s,
        t1,
        TableTotals(a: 2),
        staff,
        timing: 'before',
        pkgId: 'pk1',
        method: pmCash,
        received: 500,
        billId: 'b_2350',
        now: DateTime(2026, 11, 6, 23, 50),
      );
      s.openTables.clear();

      // Bill 2 at 00:30 on Nov 7 (still within Nov 6 business day before 05:00)
      settle(
        s,
        t1,
        TableTotals(a: 3),
        staff,
        timing: 'before',
        pkgId: 'pk1',
        method: pmCash,
        received: 1000,
        billId: 'b_0030',
        now: DateTime(2026, 11, 7, 0, 30),
      );

      final b1 = s.sales[0];
      final b2 = s.sales[1];
      expect(b1.date, '2026-11-06');
      expect(b2.date, '2026-11-06');
      expect(b1.no, '261106-001');
      expect(b2.no, '261106-002');
      // Calendar date of b2.at is still 2026-11-07 for receipt display
      expect(dkey(DateTime.parse(b2.at).toLocal()), '2026-11-07');

      final ledger = computeLedger(s, today: '2026-11-06');
      final day6 = ledger.byDate['2026-11-06']!;
      expect(day6.bills, 2);
      expect(day6.heads, 5);
      expect(day6.gross, 5 * 199);
    });
  });
}
