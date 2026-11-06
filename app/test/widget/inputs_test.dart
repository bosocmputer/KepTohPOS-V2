import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.build(brightness: Brightness.light),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('Shared Input Components', () {
    testWidgets(
      'Btn triggers onPressed when enabled and blocks when disabled',
      (tester) async {
        var tapped = 0;
        await tester.pumpWidget(
          _wrap(
            Column(
              children: [
                Btn(
                  label: 'บันทึก',
                  kind: BtnKind.primary,
                  icon: 'check',
                  onPressed: () => tapped++,
                ),
                Btn(
                  label: 'ปิดใช้งาน',
                  disabled: true,
                  onPressed: () => tapped++,
                ),
              ],
            ),
          ),
        );

        await tester.tap(find.text('บันทึก'));
        await tester.tap(find.text('ปิดใช้งาน'));
        expect(tapped, 1);
      },
    );

    testWidgets('Field and AppTextInput render label, hint, and emit text', (
      tester,
    ) async {
      var text = '';
      await tester.pumpWidget(
        _wrap(
          Field(
            label: 'หมายเหตุ',
            hint: 'ระบุความต้องการลูกค้า',
            child: AppTextInput(
              value: text,
              placeholder: 'พิมพ์ที่นี่',
              onChanged: (v) => text = v,
            ),
          ),
        ),
      );

      expect(find.text('หมายเหตุ'), findsOneWidget);
      expect(find.text('ระบุความต้องการลูกค้า'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ไม่เผ็ด');
      expect(text, 'ไม่เผ็ด');
    });

    testWidgets(
      'AppTextInput and Dropdown have identical height inside form Field',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Row(
              children: [
                Expanded(
                  child: Field(
                    label: 'ชื่อสินค้า',
                    child: AppTextInput(value: 'น้ำเปล่า', onChanged: (_) {}),
                  ),
                ),
                Expanded(
                  child: Field(
                    label: 'หน่วยนับ',
                    child: Dropdown<String>(
                      value: 'ขวด',
                      options: const [
                        DropdownOption(value: 'ขวด', label: 'ขวด'),
                      ],
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final inputH = tester.getSize(find.byType(AppTextInput)).height;
        final dropH = tester.getSize(find.byType(Dropdown<String>)).height;
        final decoratorH = tester.getSize(find.byType(InputDecorator)).height;
        final inputMatH = tester
            .getSize(
              find.descendant(
                of: find.byType(AppTextInput),
                matching: find.byType(Material),
              ),
            )
            .height;
        final dropMatH = tester
            .getSize(
              find.descendant(
                of: find.byType(Dropdown<String>),
                matching: find.byType(Material),
              ),
            )
            .height;
        expect(inputH, 44.0);
        expect(dropH, 44.0);
        expect(decoratorH, 44.0);
        expect(inputMatH, 44.0);
        expect(dropMatH, 44.0);

        final boxCenterY = tester.getCenter(find.byType(AppTextInput)).dy;
        final textCenterY = tester.getCenter(find.byType(EditableText)).dy;
        final dropTextCenterY = tester.getCenter(find.text('ขวด')).dy;
        expect((textCenterY - boxCenterY).abs(), lessThanOrEqualTo(1.0));
        expect((textCenterY - dropTextCenterY).abs(), lessThanOrEqualTo(1.0));
      },
    );

    testWidgets('Dropdown opens option list and selects value', (tester) async {
      String? selected = 'a';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => Dropdown<String>(
              value: selected,
              options: const [
                DropdownOption(value: 'a', label: 'โซน A', sub: 'ในร่ม'),
                DropdownOption(value: 'b', label: 'โซน B', sub: 'กลางแจ้ง'),
              ],
              onChanged: (v) => setState(() => selected = v),
            ),
          ),
        ),
      );

      expect(find.text('โซน A'), findsOneWidget);
      expect(find.text('โซน B'), findsNothing);

      await tester.tap(find.text('โซน A'));
      await tester.pumpAndSettle();
      expect(find.text('โซน B'), findsOneWidget);

      await tester.tap(find.text('โซน B'));
      await tester.pumpAndSettle();
      expect(selected, 'b');
    });

    testWidgets('PosStepper increments, decrements, and respects min', (
      tester,
    ) async {
      var count = 1;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => PosStepper(
              value: count,
              min: 1,
              onChanged: (v) => setState(() => count = v),
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('เพิ่ม'));
      await tester.pump();
      expect(count, 2);

      await tester.tap(find.bySemanticsLabel('ลด'));
      await tester.pump();
      expect(count, 1);

      await tester.tap(find.bySemanticsLabel('ลด'));
      await tester.pump();
      expect(count, 1);
    });

    testWidgets('Seg and Tabs switch active selection', (tester) async {
      var seg = 'before';
      var tab = 'all';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                Seg<String>(
                  value: seg,
                  items: const [
                    SegItem(value: 'before', label: 'จ่ายก่อนกิน'),
                    SegItem(value: 'after', label: 'กินก่อนจ่าย'),
                  ],
                  onChanged: (v) => setState(() => seg = v),
                ),
                Tabs<String>(
                  value: tab,
                  items: const [
                    TabItem(value: 'all', label: 'ทั้งหมด', count: 10),
                    TabItem(value: 'drink', label: 'เครื่องดื่ม', count: 6),
                  ],
                  onChanged: (v) => setState(() => tab = v),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('กินก่อนจ่าย'));
      await tester.pump();
      expect(seg, 'after');

      await tester.tap(find.text('เครื่องดื่ม'));
      await tester.pump();
      expect(tab, 'drink');
    });

    testWidgets('NumPad and PinDots handle digits, decimal, and backspace', (
      tester,
    ) async {
      var val = '';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PinDots(value: val),
                NumPad(
                  value: val,
                  maxLen: 4,
                  decimal: true,
                  onChanged: (v) => setState(() => val = v),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.tap(find.text('.'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(val, '19.5');

      // Exceeding maxLen=4 is ignored
      await tester.tap(find.text('8'));
      await tester.pump();
      expect(val, '19.5');

      await tester.tap(find.bySemanticsLabel('ลบตัวเลขท้ายสุด'));
      await tester.pump();
      expect(val, '19.');
    });
  });
}
