import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MonthPicker lists recent months and reports selection', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light),
        home: Scaffold(
          body: Center(
            child: MonthPicker(
              value: '2026-02',
              now: DateTime(2026, 2, 10),
              count: 3,
              onChanged: (v) => picked = v,
            ),
          ),
        ),
      ),
    );
    expect(find.text('กุมภาพันธ์ 2569'), findsOneWidget);
    await tester.tap(find.text('กุมภาพันธ์ 2569'));
    await tester.pumpAndSettle();
    expect(find.text('ธันวาคม 2568'), findsOneWidget);
    await tester.tap(find.text('มกราคม 2569'));
    await tester.pumpAndSettle();
    expect(picked, '2026-01');
  });
}
