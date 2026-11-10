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

      // 7. Re-open occupied pay-before-eating table A1 and verify banner notice
      await tester.tap(updatedA1Card);
      await tester.pumpAndSettle();

      final bannerCloseBtn = find.byKey(
        const ValueKey('banner-close-table-btn'),
      );
      expect(bannerCloseBtn, findsOneWidget);
      expect(find.textContaining('ชำระบุฟเฟต์แล้ว'), findsOneWidget);
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

  testWidgets(
    'after-meal (กินก่อนจ่าย) settlement auto-closes table on receipt done',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = MockPosRepository.createFallback();
      await tester.pumpWidget(KepTohApp(repository: repo));
      await tester.pumpAndSettle();

      // 1. Open free table A1 (t1) and select กินก่อนจ่าย
      await tester.tap(find.byKey(const ValueKey('table-card-t1')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('sale-timing-seg')),
          matching: find.text('กินก่อนจ่าย'),
        ),
      );
      await tester.pumpAndSettle();

      // 2. Send round and settle bill via cash
      await tester.tap(find.byKey(const ValueKey('sale-send-round-btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('sale-pay-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quick-cash-500')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pay-confirm-btn')));
      await tester.pumpAndSettle();

      // 3. Receipt done button says "เสร็จสิ้น · เก็บโต๊ะ" and clears table A1
      expect(find.text('เสร็จสิ้น · เก็บโต๊ะ'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('receipt-done-btn')));
      await tester.pumpAndSettle();

      final clearedA1Card = find.byKey(const ValueKey('table-card-t1'));
      expect(
        find.descendant(of: clearedA1Card, matching: find.text('ว่าง')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '5 feedback features: bank account picker, QR on receipt, POS slip on '
    'occupied table, and cancel when customer changes mind after printing slip',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = MockPosRepository.createFallback();
      await tester.pumpWidget(KepTohApp(repository: repo));
      await tester.pumpAndSettle();

      // 1. Open free table A1 (t1) -> go to payment step
      await tester.tap(find.byKey(const ValueKey('table-card-t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sale-pay-btn')));
      await tester.pumpAndSettle();

      // 2. Select transfer payment (pm3) -> verify BankAccountPicker appears
      await tester.tap(find.byKey(const ValueKey('pay-method-pm3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bank-account-picker')), findsOneWidget);
      expect(find.byKey(const ValueKey('bank-account-ba1')), findsOneWidget);
      expect(find.byKey(const ValueKey('bank-account-ba2')), findsOneWidget);
      expect(find.byKey(const ValueKey('transfer-status-seg')), findsNothing);
      expect(find.text('กำลังรอ'), findsNothing);

      // Select 2nd bank account (ba2 - SCB)
      await tester.tap(find.byKey(const ValueKey('bank-account-ba2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('987-6-54321-0'), findsWidgets);

      // 3. Switch to QR PromptPay (pm2) and confirm payment
      await tester.tap(find.byKey(const ValueKey('pay-method-pm2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pay-confirm-btn')));
      await tester.pumpAndSettle();

      // 4. Verify ReceiptModal renders embedded PromptPay QR on receipt card
      expect(find.byKey(const ValueKey('receipt-modal')), findsOneWidget);
      expect(find.byKey(const ValueKey('receipt-qr-box')), findsOneWidget);
      expect(find.text('สแกน QR พร้อมเพย์เพื่อชำระเงิน'), findsOneWidget);

      // Close receipt -> returns to /tables where table A1 is now occupied
      await tester.tap(find.byKey(const ValueKey('receipt-done-btn')));
      await tester.pumpAndSettle();

      // 5. On /tables, occupied table A1 shows "สลิป POS" button
      final slipBtnOnTableCard = find.byKey(
        const ValueKey('table-slip-btn-t1'),
      );
      expect(slipBtnOnTableCard, findsOneWidget);
      await tester.tap(slipBtnOnTableCard);
      await tester.pumpAndSettle();

      // Verify POS slip modal opens with QR code and void button
      expect(find.byKey(const ValueKey('receipt-modal')), findsOneWidget);
      expect(find.byKey(const ValueKey('receipt-qr-box')), findsOneWidget);

      // 6. Customer changes mind -> tap "ยกเลิกบิล" -> confirm void
      await tester.tap(find.byKey(const ValueKey('receipt-void-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-void-btn')));
      await tester.pumpAndSettle();

      // Table A1 is automatically released back to "ว่าง"
      final tableA1Card = find.byKey(const ValueKey('table-card-t1'));
      expect(
        find.descendant(of: tableA1Card, matching: find.text('ว่าง')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SalePaymentPanel allows toggling satang rounding when shop is none',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = MockPosRepository.createFallback()
        ..update(
          (s) => s.shop = s.shop.copyWith(
            vatMode: 'excluded',
            servicePct: 5,
            rounding: 'none',
          ),
        );
      await tester.pumpWidget(KepTohApp(repository: repo));
      await tester.pumpAndSettle();

      // 1. Open free table A1 (t1), add 1 child head + 1 drink (575.23)
      await tester.tap(find.byKey(const ValueKey('table-card-t1')));
      await tester.pumpAndSettle();

      final childPlus = find.descendant(
        of: find.byKey(const ValueKey('people-stepper-c')),
        matching: find.bySemanticsLabel('เพิ่ม'),
      );
      await tester.tap(childPlus);
      await tester.pumpAndSettle();

      await tester.tap(find.text('เครื่องดื่ม'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('addon-card-ad1')));
      await tester.pumpAndSettle();

      // 2. Open payment step -> verify unrounded total ฿575.23 & toggle row
      await tester.tap(find.byKey(const ValueKey('sale-pay-btn')));
      await tester.pumpAndSettle();

      final roundingToggle = find.byKey(const ValueKey('sale-rounding-toggle'));
      expect(roundingToggle, findsOneWidget);
      expect(find.text('ปัดเศษสตางค์ลง (บาทเต็ม)'), findsOneWidget);
      expect(find.text('฿575.23'), findsWidgets);

      // 3. Toggle rounding ON -> shows -฿0.23 and updates total to ฿575
      await tester.tap(roundingToggle);
      await tester.pumpAndSettle();

      expect(find.text('-฿0.23'), findsOneWidget);
      expect(find.text('฿575'), findsWidgets);

      // 4. Confirm cash payment -> settled bill is 57500 satang (-23 rounding)
      await tester.tap(find.byKey(const ValueKey('pay-confirm-btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('receipt-modal')), findsOneWidget);
      final settled = repo.state.sales.last;
      expect(settled.total, 57500);
      expect(settled.rounding, -23);
    },
  );
}
