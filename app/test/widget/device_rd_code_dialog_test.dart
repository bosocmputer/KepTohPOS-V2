import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:app/features/setup/presentation/widgets/setup_device_rd_code_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String?> saved;
  late bool? result;
  PosCommandException? failure;

  Future<void> open(WidgetTester tester, {String? current}) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showRdMachineCodeDialog(
                context,
                deviceName: 'แท็บเล็ต',
                current: current,
                onSave: (code) async {
                  if (failure != null) throw failure!;
                  saved.add(code);
                },
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('rd-code-input')), text);
    await tester.tap(find.widgetWithText(Btn, 'บันทึก'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    saved = <String?>[];
    result = null;
    failure = null;
  });

  test('rdMachineCodeError matches the database check', () {
    expect(rdMachineCodeError('ABC-123'), isNull);
    expect(rdMachineCodeError('  '), isNull);
    expect(rdMachineCodeError('ก1'), isNotNull);
    expect(rdMachineCodeError('A B'), isNotNull);
    expect(rdMachineCodeError('A' * 21), isNotNull);
  });

  testWidgets('shows the helper text and the current code', (tester) async {
    await open(tester, current: 'RD-01');

    expect(find.textContaining('ภ.พ.06'), findsOneWidget);
    expect(find.text('RD-01'), findsOneWidget);
  });

  testWidgets('an invalid code shows an error and is not saved', (
    tester,
  ) async {
    await open(tester);

    await type(tester, 'ผิด รูปแบบ');

    expect(find.textContaining('A-Z, 0-9'), findsOneWidget);
    expect(saved, isEmpty);
    expect(result, isNull);
  });

  testWidgets('a valid code is trimmed, saved and the dialog closes', (
    tester,
  ) async {
    await open(tester);

    await type(tester, ' RD-9 ');

    expect(saved, ['RD-9']);
    expect(result, isTrue);
    expect(find.byKey(const ValueKey('rd-code-input')), findsNothing);
  });

  testWidgets('an empty code is saved as null', (tester) async {
    await open(tester, current: 'RD-01');

    await type(tester, '');

    expect(saved, [null]);
    expect(result, isTrue);
  });

  testWidgets('a failed save shows the message and stays open', (tester) async {
    failure = const PosCommandException('ไม่มีสิทธิ์ทำรายการนี้');
    await open(tester);

    await type(tester, 'RD-1');

    expect(find.text('ไม่มีสิทธิ์ทำรายการนี้'), findsOneWidget);
    expect(result, isNull);
  });
}
