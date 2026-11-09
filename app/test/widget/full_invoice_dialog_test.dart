import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:app/features/bills/presentation/widgets/full_invoice_dialog.dart';
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
            onPressed: () => showFullInvoiceDialog(
              context,
              onSubmit: (n, a, t, b) async {
                if (failure != null) throw failure!;
                calls.add(<String?>[n, a, t, b]);
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

  Future<void> type(WidgetTester t, String key, String v) {
    final finder = switch (key) {
      'fullinv-taxid-input' => find.byType(AppTextInput).at(2),
      'fullinv-branch-input' => find.byType(AppTextInput).at(3),
      _ => find.byKey(ValueKey(key)),
    };
    return t.enterText(finder, v);
  }

  Future<void> submit(WidgetTester t) async {
    await t.tap(find.widgetWithText(Btn, 'ออกใบกำกับเต็มรูป'));
    await t.pumpAndSettle();
  }

  setUp(() {
    calls = <List<String?>>[];
    failure = null;
  });

  testWidgets('name and address are required', (t) async {
    await open(t);
    await submit(t);
    expect(find.text('กรุณาระบุชื่อผู้ซื้อ'), findsOneWidget);
    await type(t, 'fullinv-name-input', 'สมชาย');
    await submit(t);
    expect(find.text('กรุณาระบุที่อยู่ผู้ซื้อ'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('tax id must be exactly 13 digits', (t) async {
    await open(t);
    await type(t, 'fullinv-name-input', 'สมชาย');
    await type(t, 'fullinv-address-input', '1 ถนน');
    await type(t, 'fullinv-taxid-input', '12345');
    await submit(t);
    expect(find.text('เลขประจำตัวผู้เสียภาษีต้องมี 13 หลัก'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('branch is required when not head office', (t) async {
    await open(t);
    await type(t, 'fullinv-name-input', 'สมชาย');
    await type(t, 'fullinv-address-input', '1 ถนน');
    await type(t, 'fullinv-taxid-input', '1234567890123');
    await t.pumpAndSettle();
    await t.tap(find.byType(AppSwitch));
    await t.pumpAndSettle();
    await submit(t);
    expect(find.text('กรุณาระบุรหัสสาขา 5 หลัก'), findsOneWidget);
    await type(t, 'fullinv-branch-input', '00012');
    await submit(t);
    expect(calls.single, ['สมชาย', '1 ถนน', '1234567890123', '00012']);
  });

  testWidgets('head office sends 00000 and closes', (t) async {
    await open(t);
    await type(t, 'fullinv-name-input', 'สมชาย');
    await type(t, 'fullinv-address-input', '1 ถนน');
    await type(t, 'fullinv-taxid-input', '1234567890123');
    await submit(t);
    expect(calls.single[3], '00000');
    expect(find.widgetWithText(Btn, 'ออกใบกำกับเต็มรูป'), findsNothing);
  });

  testWidgets('offline error stays open with Thai message', (t) async {
    failure = const PosOfflineException();
    await open(t);
    await type(t, 'fullinv-name-input', 'สมชาย');
    await type(t, 'fullinv-address-input', '1 ถนน');
    await submit(t);
    expect(find.text('ต้องออนไลน์เพื่อออกใบกำกับภาษีเต็มรูป'), findsOneWidget);
    expect(find.widgetWithText(Btn, 'ออกใบกำกับเต็มรูป'), findsOneWidget);
  });
}
