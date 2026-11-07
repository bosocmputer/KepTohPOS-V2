import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/onboarding/presentation/owner_pin_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> confirmed;
  late int backs;

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: OwnerPinSetup(
                onConfirmed: confirmed.add,
                onBack: () => backs++,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> enter(WidgetTester tester, String digits) async {
    final pad = find.byKey(const ValueKey('owner-pin-pad'));
    for (final d in digits.split('')) {
      await tester.tap(find.descendant(of: pad, matching: find.text(d)));
      await tester.pump();
    }
  }

  String title(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('owner-pin-title'))).data!;

  setUp(() {
    confirmed = <String>[];
    backs = 0;
  });

  testWidgets('the same PIN twice is confirmed', (tester) async {
    // Arrange
    await pump(tester);

    // Act
    await enter(tester, '1234');
    final askedAgain = title(tester);
    await enter(tester, '1234');

    // Assert
    expect(askedAgain, 'ยืนยัน PIN อีกครั้ง');
    expect(confirmed, <String>['1234']);
  });

  testWidgets('a different second PIN starts over with a message', (
    tester,
  ) async {
    // Arrange
    await pump(tester);

    // Act
    await enter(tester, '1234');
    await enter(tester, '1235');

    // Assert
    expect(confirmed, isEmpty);
    expect(title(tester), 'ตั้ง PIN 4 หลักสำหรับเข้าใช้งานเครื่อง');
    expect(find.text('PIN ไม่ตรงกัน ลองตั้งใหม่อีกครั้ง'), findsOneWidget);

    // Act: the new PIN must be entered twice again
    await enter(tester, '5678');
    await enter(tester, '5678');

    // Assert
    expect(confirmed, <String>['5678']);
  });

  testWidgets('fewer than 4 digits does not move on; back is offered', (
    tester,
  ) async {
    // Arrange
    await pump(tester);

    // Act
    await enter(tester, '123');
    await tester.tap(find.byKey(const ValueKey('owner-pin-back-btn')));
    await tester.pump();

    // Assert
    expect(title(tester), 'ตั้ง PIN 4 หลักสำหรับเข้าใช้งานเครื่อง');
    expect(confirmed, isEmpty);
    expect(backs, 1);
  });
}
