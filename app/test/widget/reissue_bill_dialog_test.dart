import 'package:app/core/data/mock_fallback_state.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:app/features/bills/presentation/widgets/reissue_bill_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<List<String?>> calls;
  PosCommandException? failure;

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showReissueBillDialog(
              context,
              pos: buildFallbackState(DateTime(2026, 11, 9)),
              onSubmit: (r, m, a) async {
                if (failure != null) throw failure!;
                calls.add(<String?>[r, m, a]);
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('reissue-submit-btn')));
    await tester.pumpAndSettle();
  }

  Future<void> typeReason(WidgetTester tester) => tester.enterText(
    find.byKey(const ValueKey('reissue-reason-input')),
    'ผิดช่องทาง',
  );

  setUp(() {
    calls = <List<String?>>[];
    failure = null;
  });

  testWidgets('reason is required', (tester) async {
    await open(tester);
    await submit(tester);
    expect(find.text('กรุณาระบุเหตุผล'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('keeps the original method by default and closes', (t) async {
    await open(t);
    await typeReason(t);
    await submit(t);
    expect(calls, <List<String?>>[
      <String?>['ผิดช่องทาง', null, null],
    ]);
    expect(find.byKey(const ValueKey('reissue-submit-btn')), findsNothing);
  });

  testWidgets('transfer requires a bank account', (tester) async {
    await open(tester);
    await typeReason(tester);
    expect(find.byKey(const ValueKey('reissue-bank-dropdown')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reissue-method-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('โอนเงิน').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reissue-bank-dropdown')), findsOneWidget);
    await submit(tester);
    expect(find.text('กรุณาเลือกบัญชีธนาคาร'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('offline error stays in the dialog', (tester) async {
    failure = const PosOfflineException();
    await open(tester);
    await typeReason(tester);
    await submit(tester);
    expect(find.text('ต้องออนไลน์เพื่อออกใบใหม่แทน'), findsOneWidget);
    expect(find.byKey(const ValueKey('reissue-submit-btn')), findsOneWidget);
  });

  testWidgets('command error is shown and dialog stays', (tester) async {
    failure = const PosCommandException('บิลนี้ถูกยกเลิกแล้ว');
    await open(tester);
    await typeReason(tester);
    await submit(tester);
    expect(find.text('บิลนี้ถูกยกเลิกแล้ว'), findsOneWidget);
    expect(find.byKey(const ValueKey('reissue-submit-btn')), findsOneWidget);
  });
}
