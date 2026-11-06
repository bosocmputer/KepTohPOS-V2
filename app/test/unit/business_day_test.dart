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

  group(
    'Item 3 + B3: Calendar vs Custom fixedCostDivisor & Monthly deducted',
    () {
      test(
        'calendar divisor divides activeFixedSum by 28, 29, 30, and 31 days',
        () {
          final repo = MockPosRepository.createFallback(
            now: DateTime(2026, 11, 6, 12),
          );
          BillRecord saleOn(String d) => BillRecord(
            id: 'b-$d',
            no: '001',
            date: d,
            at: '${d}T18:00:00Z',
            tableId: 't1',
            tableName: 'A1',
            staffId: 'st1',
            staffName: 'อัย',
            packageId: 'pk1',
            lines: const <OrderLineItem>[],
            subtotal: 199,
            service: 0,
            vat: 0,
            rounding: 0,
            total: 199,
            heads: HeadsCount(a: 1),
            methodId: 'pm1',
            methodName: 'เงินสด',
            methodType: 'cash',
            received: 200,
            change: 1,
            vatMode: 'none',
            vatRate: 0,
          );
          final s = repo.state.copy()
            ..shop = repo.state.shop.copyWith(
              fixedCostDivisor: 'calendar',
              openDaysPerMonth: 25,
            )
            ..fixedCosts.add(
              const FixedCostItem(id: 'fc1', name: 'ค่าเช่า+ไฟ', amount: 46100),
            )
            ..sales.addAll([
              saleOn('2026-02-01'),
              saleOn('2028-02-01'),
              saleOn('2026-11-01'),
              saleOn('2026-10-01'),
            ])
            ..startDate = '2026-02-01';

          // Feb 2026 (non-leap = 28 days)
          final ledFeb26 = computeLedger(s, today: '2026-02-01');
          expect(
            ledFeb26.byDate['2026-02-01']!.fixed,
            closeTo(46100 / 28, 1e-6),
          );

          // Feb 2028 (leap year = 29 days)
          s.startDate = '2028-02-01';
          final ledFeb28 = computeLedger(s, today: '2028-02-01');
          expect(
            ledFeb28.byDate['2028-02-01']!.fixed,
            closeTo(46100 / 29, 1e-6),
          );

          // Nov 2026 (30 days)
          s.startDate = '2026-11-01';
          final ledNov = computeLedger(s, today: '2026-11-01');
          expect(ledNov.byDate['2026-11-01']!.fixed, closeTo(46100 / 30, 1e-6));

          // Oct 2026 (31 days)
          s.startDate = '2026-10-01';
          final ledOct = computeLedger(s, today: '2026-10-01');
          expect(ledOct.byDate['2026-10-01']!.fixed, closeTo(46100 / 31, 1e-6));

          // Custom mode uses openDaysPerMonth (25)
          s.shop = s.shop.copyWith(fixedCostDivisor: 'custom');
          final ledCustom = computeLedger(s, today: '2026-10-01');
          expect(
            ledCustom.byDate['2026-10-01']!.fixed,
            closeTo(46100 / 25, 1e-6),
          );
        },
      );

      test('computeMonthlyReport tracks fixedDeducted vs fixedFullMonth', () {
        final repo = MockPosRepository.createFallback(
          now: DateTime(2026, 11, 6, 12),
        );
        final s = repo.state.copy()
          ..startDate = '2026-11-05'
          ..shop = repo.state.shop.copyWith(fixedCostDivisor: 'calendar')
          ..fixedCosts.add(
            const FixedCostItem(id: 'fc1', name: 'ค่าคงที่', amount: 46100),
          )
          ..sales.add(
            BillRecord(
              id: 'b1',
              no: '001',
              date: '2026-11-06',
              at: '2026-11-06T18:00:00Z',
              tableId: 't1',
              tableName: 'A1',
              staffId: 'st1',
              staffName: 'อัย',
              packageId: 'pk1',
              lines: const <OrderLineItem>[],
              subtotal: 199,
              service: 0,
              vat: 0,
              rounding: 0,
              total: 199,
              heads: HeadsCount(a: 1),
              methodId: 'pm1',
              methodName: 'เงินสด',
              methodType: 'cash',
              received: 200,
              change: 1,
              vatMode: 'none',
              vatRate: 0,
            ),
          )
          ..counts['2026-11-06'] = <String, double>{};

        final led = computeLedger(s, today: '2026-11-06');
        final rep = computeMonthlyReport(s, led, month: '2026-11');
        expect(rep.closedDays.length, 1);
        expect(rep.salesDays, 1);
        expect(rep.fixedFullMonth, 46100);
        expect(rep.fixedDeducted, closeTo(46100 / 30, 1e-6));
        expect(rep.fixedDeducted < rep.fixedFullMonth, isTrue);
      });
    },
  );
}
