// Expected numbers in this test file were generated directly from the JS
// reference implementation in `prototype/index.html` (lines 450-763 and
// 1791-1799) + `prototype/data/mock-data.js` executed via Node.js (`node -e`)
// with fixed timestamp `new Date(2026, 10, 4, 12, 0, 0, 0)`.
import 'dart:convert';
import 'dart:io';

import 'package:app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

PosState _loadFreshMockState(DateTime now) {
  Map<String, dynamic> readObj(String name) =>
      jsonDecode(File('assets/mock/$name.json').readAsStringSync())
          as Map<String, dynamic>;
  List<Map<String, dynamic>> readList(String name) => (jsonDecode(
    File('assets/mock/$name.json').readAsStringSync(),
  ) as List<dynamic>).cast<Map<String, dynamic>>();

  return PosState(
    startDate: dkey(now),
    shop: ShopConfig.fromJson(readObj('shop')),
    packages: readList('packages').map(PackageItem.fromJson).toList(),
    addons: readList('addons').map(AddonItem.fromJson).toList(),
    suppliers: readList('suppliers').map(SupplierItem.fromJson).toList(),
    ingredients: readList('ingredients').map(IngredientItem.fromJson).toList(),
    tables: readList('tables').map(DiningTable.fromJson).toList(),
    staff: readList('staff').map(StaffMember.fromJson).toList(),
    payments: readList('payments').map(PaymentMethod.fromJson).toList(),
    expenseTypes: readList('expense_types').map(ExpenseType.fromJson).toList(),
    fixedCosts: readList('fixed_costs').map(FixedCostItem.fromJson).toList(),
  );
}

void main() {
  group('ROLE & VIEWS permissions parity with prototype/index.html', () {
    test('owner and manager access all 7 views; cashier accesses 4 views', () {
      expect(kRoles.keys, containsAll(['owner', 'manager', 'cashier']));
      expect(
        allowedViewsForRole('owner').map((v) => v.id).toList(),
        equals([
          'tables',
          'bills',
          'stock',
          'shift',
          'dashboard',
          'reports',
          'setup',
        ]),
      );
      expect(
        allowedViewsForRole('manager').map((v) => v.id).toList(),
        equals([
          'tables',
          'bills',
          'stock',
          'shift',
          'dashboard',
          'reports',
          'setup',
        ]),
      );
      expect(
        allowedViewsForRole('cashier').map((v) => v.id).toList(),
        equals(['tables', 'bills', 'stock', 'shift']),
      );
      expect(canAccessViewId('cashier', 'reports'), isFalse);
      expect(canAccessViewId('cashier', 'tables'), isTrue);
    });
  });

  group('calcOrder parity (VAT none/included/excluded & rounding)', () {
    late PosState base;

    setUp(() {
      base = _loadFreshMockState(DateTime(2026, 11, 4, 12));
    });

    test(
      'VAT none, service 0%, rounding down (pk1, a:2 c:1 f:1, ad1x2 ad5x1)',
      () {
        final pkg1 = base.packages.firstWhere((p) => p.id == 'pk1');
        final ad1 = base.addons.firstWhere((x) => x.id == 'ad1');
        final ad5 = base.addons.firstWhere((x) => x.id == 'ad5');
        final res = calcOrder(base.shop, pkg1, 2, 1, 1, <AddonLineInput>[
          AddonLineInput(addon: ad1, qty: 2),
          AddonLineInput(addon: ad5, qty: 1),
        ]);
        expect(res.subtotal, 607);
        expect(res.service, 0);
        expect(res.vat, 0);
        expect(res.rounding, 0);
        expect(res.total, 607);
        expect(res.lines.length, 5);
      },
    );

    test(
      'VAT excluded, service 5%, rounding down vs none (pk1, a:2 c:1, ad1x1)',
      () {
        final pkg1 = base.packages.firstWhere((p) => p.id == 'pk1');
        final ad1 = base.addons.firstWhere((x) => x.id == 'ad1');
        final shopDown = base.shop.copyWith(
          vatMode: 'excluded',
          servicePct: 5,
          rounding: 'down',
        );
        final resDown = calcOrder(shopDown, pkg1, 2, 1, 0, <AddonLineInput>[
          AddonLineInput(addon: ad1, qty: 1),
        ]);
        expect(resDown.subtotal, 512);
        expect(resDown.service, 25.6);
        expect(resDown.vat, 37.63);
        expect(resDown.rounding, -0.23);
        expect(resDown.total, 575);

        final shopNone = shopDown.copyWith(rounding: 'none');
        final resNone = calcOrder(shopNone, pkg1, 2, 1, 0, <AddonLineInput>[
          AddonLineInput(addon: ad1, qty: 1),
        ]);
        expect(resNone.subtotal, 512);
        expect(resNone.service, 25.6);
        expect(resNone.vat, 37.63);
        expect(resNone.rounding, 0);
        expect(resNone.total, 575.23);
      },
    );

    test(
      'VAT included, service 10%, rounding down (pk2, a:3 c:2 f:1, ad5x2)',
      () {
        final pkg2 = base.packages.firstWhere((p) => p.id == 'pk2');
        final ad5 = base.addons.firstWhere((x) => x.id == 'ad5');
        final shopInc = base.shop.copyWith(
          vatMode: 'included',
          servicePct: 10,
          rounding: 'down',
        );
        final res = calcOrder(shopInc, pkg2, 3, 2, 1, <AddonLineInput>[
          AddonLineInput(addon: ad5, qty: 2),
        ]);
        expect(res.subtotal, 1275);
        expect(res.service, 127.5);
        expect(res.vat, 91.72);
        expect(res.rounding, -0.5);
        expect(res.total, 1402);
      },
    );
  });

  group('Order & Settlement flows: before vs after (rounds & adjustments)', () {
    test('pay-before-eating (before) and eat-before-paying (after) parity', () {
      final fixedNow = DateTime(2026, 11, 4, 12);
      final s = _loadFreshMockState(fixedNow);
      final me = s.staff.first;
      final t1 = s.tables.firstWhere((t) => t.id == 't1');
      final t2 = s.tables.firstWhere((t) => t.id == 't2');
      final pmCash = s.payments.firstWhere((p) => p.id == 'pm1');
      final pmQr = s.payments.firstWhere((p) => p.id == 'pm2');
      final pkg2 = s.packages.firstWhere((p) => p.id == 'pk2');
      int stockOf(String id) => s.addons.firstWhere((x) => x.id == id).stock;

      // Initial stock from mock-data.js (ad1=96, ad5=60)
      expect(stockOf('ad1'), 96);
      expect(stockOf('ad5'), 60);

      // 1. Pay-before-eating on t1 (deducts stock on settle: ad1=94, ad5=59)
      settle(
        s,
        t1,
        TableTotals(a: 2, c: 1, f: 1, ad: {'ad1': 2, 'ad5': 1}),
        me,
        timing: 'before',
        pkgId: 'pk1',
        method: pmCash,
        received: 1000,
        billId: 'b1',
        notes: 'test before',
        now: fixedNow,
      );
      expect(stockOf('ad1'), 94);
      expect(stockOf('ad5'), 59);

      expect(s.sales.length, 1);
      final bill1 = s.sales.first;
      expect(bill1.no, '261104-001');
      expect(bill1.total, 607);
      expect(bill1.received, 1000);
      expect(bill1.change, 393);
      expect(s.openTables['t1']?.billIds, contains('b1'));

      // 2. Eat-before-paying on t2 (sendRound deducts stock immediately)
      sendRound(
        s,
        t2,
        TableTotals(a: 3, c: 1, ad: {'ad1': 3, 'ad5': 2}),
        me,
        'after',
        'pk2',
        'round 1',
        now: fixedNow,
      );
      expect(stockOf('ad1'), 91);
      expect(stockOf('ad5'), 57);

      sendRound(
        s,
        t2,
        TableTotals(a: 1, ad: {'ad5': 1}),
        me,
        'after',
        'pk2',
        'round 2',
        now: fixedNow,
      );
      expect(stockOf('ad1'), 91);
      expect(stockOf('ad5'), 56);

      final ot = s.openTables['t2']!;
      final totBefore = tableTotals(ot);
      expect(totBefore.a, 4);
      expect(totBefore.c, 1);
      expect(totBefore.ad, {'ad1': 3, 'ad5': 3});
      expect(tableDue(s, ot), 1540);

      // adjustSent restores stock for addon (ad5 + 1 = 57)
      adjustSent(s, 't2', 'head', 'a', 1, 'ลดหัวผู้ใหญ่ 1', me, now: fixedNow);
      adjustSent(s, 't2', 'addon', 'ad5', 1, 'คืนเบียร์ 1', me, now: fixedNow);
      expect(stockOf('ad1'), 91);
      expect(stockOf('ad5'), 57);

      final totAfter = tableTotals(ot);
      expect(totAfter.a, 3);
      expect(totAfter.c, 1);
      expect(totAfter.ad, {'ad1': 3, 'ad5': 2});
      expect(tableDue(s, ot), 1181);

      final lines = sentLines(s, pkg2, totAfter);
      expect(lines.length, 4);
      expect(lines.map((l) => l.qty).toList(), [3, 1, 3, 2]);

      final extraCart = TableTotals(ad: {'ad1': 1});
      final merged = mergeTotals(totAfter, extraCart);
      expect(merged.ad['ad1'], 4);

      settle(
        s,
        t2,
        extraCart,
        me,
        timing: 'after',
        pkgId: 'pk2',
        method: pmQr,
        received: 0,
        billId: 'b2',
        notes: 'settle after',
        now: fixedNow,
      );
      expect(stockOf('ad1'), 90);
      expect(stockOf('ad5'), 57);

      final bill2 = s.sales.last;
      expect(bill2.no, '261104-002');
      expect(bill2.total, 1196);
      expect(bill2.received, 1196);
      expect(bill2.change, 0);
      expect(ot.rounds, isEmpty);
      expect(ot.adjusts, isEmpty);
      expect(ot.log.length, 2);

      // 3. Verify PromptPay QR payload for settled bill totals (607 & 1196)
      expect(
        promptPayPayload(s.shop.promptpay, bill1.total),
        '00020101021229370016A00000067701011101130066812345678'
        '53037645406607.005802TH6304E9DB',
      );
      expect(
        promptPayPayload(s.shop.promptpay, bill2.total),
        '00020101021229370016A00000067701011101130066812345678'
        '530376454071196.005802TH6304FA97',
      );
    });

    test(
      'voidBill sets metadata, reduces computeLedger sales/profit, restores '
      'addon stock for before & after (with adjustSent), and is idempotent',
      () {
        final fixedNow = DateTime(2026, 11, 4, 12);
        final voidTime = DateTime(2026, 11, 4, 13, 30);
        final s = _loadFreshMockState(fixedNow);
        final owner = s.staff.firstWhere((st) => st.role == 'owner');
        final cashier = s.staff.firstWhere((st) => st.role == 'cashier');
        final t1 = s.tables.firstWhere((t) => t.id == 't1');
        final t2 = s.tables.firstWhere((t) => t.id == 't2');
        final pmCash = s.payments.firstWhere((p) => p.id == 'pm1');
        final pmQr = s.payments.firstWhere((p) => p.id == 'pm2');
        int stockOf(String id) => s.addons.firstWhere((x) => x.id == id).stock;

        expect(stockOf('ad1'), 96);
        expect(stockOf('ad5'), 60);

        // 1. Settle 'before' bill b1 (ad1: 2, ad5: 1 -> ad1=94, ad5=59)
        settle(
          s,
          t1,
          TableTotals(a: 2, c: 1, f: 1, ad: {'ad1': 2, 'ad5': 1}),
          owner,
          timing: 'before',
          pkgId: 'pk1',
          method: pmCash,
          received: 1000,
          billId: 'b1',
          now: fixedNow,
        );
        expect(stockOf('ad1'), 94);
        expect(stockOf('ad5'), 59);

        // 2. Settle 'after' bill b2 with sendRound + adjustSent + extraCart
        sendRound(
          s,
          t2,
          TableTotals(a: 3, c: 1, ad: {'ad1': 3, 'ad5': 3}),
          owner,
          'after',
          'pk2',
          '',
          now: fixedNow,
        );
        expect(stockOf('ad1'), 91);
        expect(stockOf('ad5'), 56);

        // adjustSent reduces ad5 by 1 -> stock ad5=57, net ad5 on table = 2
        adjustSent(
          s,
          't2',
          'addon',
          'ad5',
          1,
          'คืนเบียร์ 1',
          owner,
          now: fixedNow,
        );
        expect(stockOf('ad5'), 57);

        // Settle with extraCart ad1: 1 -> stock ad1=90, ad5=57
        settle(
          s,
          t2,
          TableTotals(ad: {'ad1': 1}),
          owner,
          timing: 'after',
          pkgId: 'pk2',
          method: pmQr,
          received: 0,
          billId: 'b2',
          now: fixedNow,
        );
        expect(stockOf('ad1'), 90);
        expect(stockOf('ad5'), 57);

        // Close day counts so computeLedger computes gross & net profit
        s.counts['2026-11-04'] = <String, double>{
          for (final ing in s.ingredients) ing.id: 0,
        };

        final ledgerBefore = computeLedger(s, today: '2026-11-04');
        final dayBefore = ledgerBefore.days.firstWhere(
          (d) => d.date == '2026-11-04',
        );
        expect(dayBefore.gross, 607 + 1196);
        expect(dayBefore.bills, 2);

        // Cashier cannot void
        expect(
          voidBill(
            s,
            billId: 'b1',
            me: cashier,
            reason: 'ทดลอง',
            now: voidTime,
          ),
          isFalse,
        );
        expect(s.sales.firstWhere((b) => b.id == 'b1').voided, isFalse);
        expect(stockOf('ad1'), 90);

        // Void b1 ('before' mode) as owner -> restores ad1 +2 (92), ad5 +1 (58)
        expect(
          voidBill(
            s,
            billId: 'b1',
            me: owner,
            reason: 'คีย์จำนวนคนผิด',
            now: voidTime,
          ),
          isTrue,
        );
        final bill1 = s.sales.firstWhere((b) => b.id == 'b1');
        expect(bill1.voided, isTrue);
        expect(bill1.voidBy, owner.name);
        expect(bill1.voidReason, 'คีย์จำนวนคนผิด');
        expect(bill1.voidAt, voidTime.toUtc().toIso8601String());
        expect(stockOf('ad1'), 92);
        expect(stockOf('ad5'), 58);

        final ledgerAfterB1 = computeLedger(s, today: '2026-11-04');
        final dayAfterB1 = ledgerAfterB1.days.firstWhere(
          (d) => d.date == '2026-11-04',
        );
        expect(dayAfterB1.gross, 1196);
        expect(dayAfterB1.bills, 1);
        expect(dayBefore.profit! - dayAfterB1.profit!, greaterThan(0));

        // Voiding b1 again is a no-op and does not restore stock twice
        expect(
          voidBill(s, billId: 'b1', me: owner, reason: 'ซ้ำ', now: voidTime),
          isFalse,
        );
        expect(stockOf('ad1'), 92);
        expect(stockOf('ad5'), 58);
        expect(bill1.voidReason, 'คีย์จำนวนคนผิด');

        // Void b2 ('after' mode with adjustSent) -> restores ad1 +4, ad5 +2
        expect(voidBill(s, billId: 'b2', me: owner, now: voidTime), isTrue);
        final bill2 = s.sales.firstWhere((b) => b.id == 'b2');
        expect(bill2.voided, isTrue);
        expect(bill2.voidReason, 'ไม่ระบุ');
        expect(stockOf('ad1'), 96);
        expect(stockOf('ad5'), 60);
      },
    );
  });
}
