import 'package:app/app.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'free table -> select package -> add heads & drink -> send round',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = MockPosRepository.createFallback();
      await tester.pumpWidget(KepTohApp(repository: repo));
      await tester.pumpAndSettle();

      // 1. Verify free table A1 (t1) on /tables shows "ว่าง"
      final tableA1Card = find.byKey(const ValueKey('table-card-t1'));
      expect(tableA1Card, findsOneWidget);
      expect(
        find.descendant(of: tableA1Card, matching: find.text('ว่าง')),
        findsOneWidget,
      );

      // 2. Tap free table A1 -> opens SalePage (/tables/t1)
      await tester.tap(tableA1Card);
      await tester.pumpAndSettle();

      // 3. Ensure 'after' mode and select package หมู + ทะเล (pk2)
      final timingSeg = find.byKey(const ValueKey('sale-timing-seg'));
      if (timingSeg.evaluate().isNotEmpty) {
        await tester.tap(
          find.descendant(of: timingSeg, matching: find.text('กินก่อนจ่าย')),
        );
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const ValueKey('pkg-card-pk2')));
      await tester.pumpAndSettle();

      // 4. Add 1 adult head and 1 child head via PeopleRow steppers
      final adultPlus = find.descendant(
        of: find.byKey(const ValueKey('people-stepper-a')),
        matching: find.bySemanticsLabel('เพิ่ม'),
      );
      await tester.tap(adultPlus);
      await tester.pumpAndSettle();

      final childPlus = find.descendant(
        of: find.byKey(const ValueKey('people-stepper-c')),
        matching: find.bySemanticsLabel('เพิ่ม'),
      );
      await tester.tap(childPlus);
      await tester.pumpAndSettle();

      // 5. Switch category tab to เครื่องดื่ม and tap addon card ad1
      await tester.tap(find.text('เครื่องดื่ม'));
      await tester.pumpAndSettle();

      final drinkCard = find.byKey(const ValueKey('addon-card-ad1'));
      await tester.ensureVisible(drinkCard);
      await tester.tap(drinkCard);
      await tester.pumpAndSettle();

      // 6. Send round (ส่งออเดอร์)
      final sendRoundBtn = find.byKey(const ValueKey('sale-send-round-btn'));
      expect(sendRoundBtn, findsOneWidget);
      await tester.tap(sendRoundBtn);
      await tester.pumpAndSettle();

      // 7. Return to /tables and verify A1 status is now "มีลูกค้า"
      await tester.tap(find.byKey(const ValueKey('sale-back-tables-btn')));
      await tester.pumpAndSettle();

      final updatedA1Card = find.byKey(const ValueKey('table-card-t1'));
      expect(updatedA1Card, findsOneWidget);
      expect(
        find.descendant(of: updatedA1Card, matching: find.text('มีลูกค้า')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'select table -> order -> pay cash -> see receipt -> return to /tables',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = MockPosRepository.createFallback();
      await tester.pumpWidget(KepTohApp(repository: repo));
      await tester.pumpAndSettle();

      // 1. Tap free table A1 (t1) on /tables -> opens /tables/t1
      await tester.tap(find.byKey(const ValueKey('table-card-t1')));
      await tester.pumpAndSettle();

      // 2. Switch to drink tab and add 1 water (ad1 = 15) on top of 2 adults
      await tester.tap(find.text('เครื่องดื่ม'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('addon-card-ad1')));
      await tester.pumpAndSettle();

      // 3. Tap primary pay button -> opens SalePaymentPanel
      await tester.tap(find.byKey(const ValueKey('sale-pay-btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sale-payment-panel')), findsOneWidget);

      // 4. Tap quick cash 500 button and confirm cash payment
      await tester.tap(find.byKey(const ValueKey('quick-cash-500')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pay-confirm-btn')));
      await tester.pumpAndSettle();

      // 5. Verify ReceiptModal is shown with receipt details
      expect(find.byKey(const ValueKey('receipt-modal')), findsOneWidget);
      expect(find.byKey(const ValueKey('receipt-card')), findsOneWidget);
      expect(find.text('รับเงินเรียบร้อย'), findsWidgets);

      // 6. Tap "เสร็จสิ้น" -> returns to /tables and table A1 shows "มีลูกค้า"
      await tester.tap(find.byKey(const ValueKey('receipt-done-btn')));
      await tester.pumpAndSettle();

      final updatedA1Card = find.byKey(const ValueKey('table-card-t1'));
      expect(updatedA1Card, findsOneWidget);
      expect(
        find.descendant(of: updatedA1Card, matching: find.text('มีลูกค้า')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'opening zone dropdown on /tables floats in overlay without shifting StatsGroup',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = MockPosRepository.createFallback();
      await tester.pumpWidget(KepTohApp(repository: repo));
      await tester.pumpAndSettle();

      final statsFinder = find.text('โต๊ะว่าง');
      final beforeTopLeft = tester.getTopLeft(statsFinder);

      await tester.tap(find.byKey(const ValueKey('tables-zone-dropdown')));
      await tester.pumpAndSettle();

      final afterTopLeft = tester.getTopLeft(statsFinder);
      expect(afterTopLeft, equals(beforeTopLeft));
    },
  );
}
