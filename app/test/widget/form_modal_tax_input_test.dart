import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.build(brightness: Brightness.light),
  home: Scaffold(body: child),
);

class _Host extends StatefulWidget {
  const new();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String tax = '';
  String branch = '00000';
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: TaxIdBranchInput(
      taxId: tax,
      branchCode: branch,
      onChanged: (t, b) => setState(() {
        tax = t;
        branch = b;
      }),
    ),
  );
}

void main() {
  testWidgets('FormModal buttons, error, submit', (tester) async {
    var saved = 0;
    var cancelled = 0;
    await tester.pumpWidget(
      _wrap(
        FormModal(
          title: 'แก้ไข',
          error: 'ผิดพลาด',
          onSubmit: () => saved++,
          onCancel: () => cancelled++,
          children: const [Text('field')],
        ),
      ),
    );
    expect(find.text('ผิดพลาด'), findsOneWidget);
    await tester.tap(find.text('บันทึก'));
    await tester.tap(find.text('ยกเลิก'));
    expect((saved, cancelled), (1, 1));
  });

  testWidgets('FormModal busy disables actions; disabled blocks submit', (
    tester,
  ) async {
    var saved = 0;
    var cancelled = 0;
    Widget build({bool busy = false, bool dis = false}) => _wrap(
      FormModal(
        title: 't',
        busy: busy,
        submitDisabled: dis,
        onSubmit: () => saved++,
        onCancel: () => cancelled++,
        children: const [],
      ),
    );
    await tester.pumpWidget(build(busy: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('ยกเลิก'));
    await tester.tap(find.text('บันทึก'), warnIfMissed: false);
    expect((saved, cancelled), (0, 0));
    await tester.pumpWidget(build(dis: true));
    await tester.tap(find.text('บันทึก'));
    expect(saved, 0);
  });

  testWidgets('TaxIdBranchInput HQ toggle, branch and tax validation', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const _Host()));
    expect(find.text('รหัสสาขา'), findsNothing);
    await tester.tap(find.text('สำนักงานใหญ่'));
    await tester.pump();
    expect(find.text('รหัสสาขา'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.last, '123');
    await tester.pump();
    expect(find.text('รหัสสาขาต้องมี 5 หลัก'), findsOneWidget);
    await tester.enterText(fields.last, '00001');
    await tester.pump();
    expect(find.text('รหัสสาขาต้องมี 5 หลัก'), findsNothing);
    await tester.enterText(fields.first, '123');
    await tester.pump();
    expect(find.text('เลขประจำตัวผู้เสียภาษีต้องมี 13 หลัก'), findsOneWidget);
    await tester.enterText(fields.first, '0105561234567');
    await tester.pump();
    expect(find.text('เลขประจำตัวผู้เสียภาษีต้องมี 13 หลัก'), findsNothing);
    await tester.tap(find.text('สำนักงานใหญ่'));
    await tester.pump();
    expect(find.text('รหัสสาขา'), findsNothing);
  });
}
