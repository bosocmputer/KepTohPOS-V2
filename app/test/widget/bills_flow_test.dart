import 'package:app/app.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tap bill row -> open receipt -> void bill with reason -> '
      'row shows "ยกเลิก" and summary sales decreases', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fixedNow = DateTime(2026, 11, 4, 18);
    final repo = MockPosRepository.createFallback(now: fixedNow)
      ..update((s) {
        final pkg = s.packages.first;
        final pmCash = s.payments.first;
        final order1 = calcOrder(s.shop, pkg, 2, 0, 0, <AddonLineInput>[
          AddonLineInput(addon: s.addons.first, qty: 2),
        ]);
        final order2 = calcOrder(
          s.shop,
          pkg,
          1,
          0,
          0,
          const <AddonLineInput>[],
        );
        settle(
          s,
          s.tables.first,
          TableTotals(a: 2, ad: {'ad1': 2}),
          s.staff.first,
          timing: 'before',
          pkgId: pkg.id,
          method: pmCash,
          received: order1.total,
          billId: 'b1',
          now: fixedNow.subtract(const Duration(minutes: 10)),
        );
        settle(
          s,
          s.tables.first,
          TableTotals(a: 1),
          s.staff.first,
          timing: 'before',
          pkgId: pkg.id,
          method: pmCash,
          received: order2.total,
          billId: 'b2',
          now: fixedNow,
        );
      });

    // b1 = 428, b2 = 199 -> initial totalSales = 627, stock ad1 = 94
    expect(repo.state.addons.first.stock, 94);

    await tester.pumpWidget(
      KepTohApp(repository: repo, initialLocation: '/bills'),
    );
    await tester.pumpAndSettle();

    final statsGroup = find.byKey(const ValueKey('bills-stats-group'));

    // Verify initial summary sales is ฿627 and 2 bills
    expect(
      find.descendant(of: statsGroup, matching: find.text('฿627')),
      findsOneWidget,
    );
    expect(find.text('ไม่มีบิลยกเลิก'), findsOneWidget);

    // 1. Tap row for b1 (261104-001, ฿428.00) -> opens ReceiptModal
    await tester.tap(find.byKey(const ValueKey('bill-row-no-b1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-modal')), findsOneWidget);

    // 2. Tap "ยกเลิกบิล" button -> shows void confirmation form
    final voidBtn = find.byKey(const ValueKey('receipt-void-btn'));
    expect(voidBtn, findsOneWidget);
    await tester.tap(voidBtn);
    await tester.pumpAndSettle();

    // 3. Enter reason and confirm void
    final reasonField = find.descendant(
      of: find.byKey(const ValueKey('void-reason-input')),
      matching: find.byType(TextField),
    );
    await tester.enterText(reasonField, 'คีย์จำนวนคนผิด');
    await tester.pumpAndSettle();

    final confirmBtn = find.byKey(const ValueKey('confirm-void-btn'));
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // 4. Close ReceiptModal
    await tester.tap(find.byKey(const ValueKey('receipt-done-btn')));
    await tester.pumpAndSettle();

    // 5. Row shows "ยกเลิก" pill, summary sales is ฿199, stock returned to 96
    expect(find.text('ยกเลิก'), findsWidgets);
    expect(find.text('ยกเลิก 1 บิล'), findsOneWidget);
    expect(
      find.descendant(of: statsGroup, matching: find.text('฿199')),
      findsOneWidget,
    );
    expect(repo.state.addons.first.stock, 96);
  });
}
