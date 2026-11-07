import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/dev_components_page.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.build(brightness: Brightness.light),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('Shared Display & Overlay Components', () {
    testWidgets('Pill, Stat, StatsGroup, Empty, and ResultState render', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              Pill(label: 'กำลังทาน', tone: PillTone.orange, showDot: true),
              StatsGroup(
                children: [
                  Stat(label: 'ยอดขาย', value: '฿12,000'),
                  Stat(label: 'กำไร', value: '฿4,500', tone: StatTone.green),
                ],
              ),
              Empty(title: 'ไม่พบบิล', text: 'ลองเปลี่ยนตัวกรอง'),
              ResultState(title: 'ชำระเงินสำเร็จ', text: 'บันทึกบิลแล้ว'),
            ],
          ),
        ),
      );

      expect(find.text('กำลังทาน'), findsOneWidget);
      expect(find.text('ยอดขาย'), findsOneWidget);
      expect(find.text('฿12,000'), findsOneWidget);
      expect(find.text('ไม่พบบิล'), findsOneWidget);
      expect(find.text('ชำระเงินสำเร็จ'), findsOneWidget);
    });

    testWidgets('PosDataTable and Pagination render rows and change pages', (
      tester,
    ) async {
      var page = 1;
      var tappedRow = '';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                PosDataTable<String>(
                  columns: [
                    DataTableCol(
                      key: 'id',
                      label: 'รหัส',
                      cellBuilder: (_, r) => Text(r),
                    ),
                  ],
                  rows: const ['B-001', 'B-002'],
                  onRowTap: (r) => tappedRow = r,
                ),
                Pagination(
                  page: page,
                  pages: 3,
                  onChanged: (n) => setState(() => page = n),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('B-002'));
      expect(tappedRow, 'B-002');

      await tester.tap(find.text('3'));
      await tester.pump();
      expect(page, 3);
      expect(find.text('หน้า 3 จาก 3'), findsOneWidget);
    });

    testWidgets('Modal, Confirm, AppToast, and ProductCard work accurately', (
      tester,
    ) async {
      var confirmed = false;
      var cancelled = false;
      var cardTapped = false;

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              Modal(
                title: 'แก้ไขข้อมูล',
                sub: 'โต๊ะ A1',
                onClose: () {},
                child: const Text('รายละเอียด'),
              ),
              Confirm(
                title: 'ยืนยันการยกเลิกบิล',
                text: 'ต้องการยกเลิกใช่หรือไม่',
                danger: true,
                onYes: () => confirmed = true,
                onNo: () => cancelled = true,
              ),
              ProductCard(
                name: 'สามชั้นสไลซ์',
                category: 'หมู',
                price: 5900,
                stock: 10,
                onTap: () => cardTapped = true,
              ),
              const AppToast(message: 'บันทึกสำเร็จ'),
            ],
          ),
        ),
      );

      await tester.tap(find.text('ยืนยัน'));
      expect(confirmed, isTrue);

      await tester.tap(find.text('ยกเลิก'));
      expect(cancelled, isTrue);

      await tester.tap(find.text('สามชั้นสไลซ์'));
      expect(cardTapped, isTrue);
      expect(find.text('บันทึกสำเร็จ'), findsOneWidget);
    });

    testWidgets('DevComponentsPage renders both Light and Dark panes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(brightness: Brightness.light),
          home: const DevComponentsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('คลัง Component กลาง · โหมดสว่าง (Light)'),
        findsOneWidget,
      );
      expect(find.text('คลัง Component กลาง · โหมดมืด (Dark)'), findsOneWidget);
    });
  });
}
