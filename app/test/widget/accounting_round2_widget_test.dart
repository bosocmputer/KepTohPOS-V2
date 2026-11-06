import 'dart:io';

import 'package:app/app.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/widgets/btn.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/tables/presentation/pages/tables_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

PosRepository _buildFullRepo({
  required DateTime fixedNow,
  String sessionStaffId = 'st1',
}) {
  const keys = <String>[
    'shop',
    'packages',
    'addons',
    'suppliers',
    'ingredients',
    'tables',
    'staff',
    'payments',
    'expense_types',
    'fixed_costs',
  ];
  final jsonByName = <String, String>{
    for (final k in keys) k: File('assets/mock/$k.json').readAsStringSync(),
  };
  return MockPosRepository.fromJsonStrings(
    jsonByName,
    now: fixedNow,
    sessionStaffId: sessionStaffId,
  );
}

void main() {
  testWidgets(
    'Table POS slip with 7 heads + 1 added head opens TableSummaryModal '
    'with eat-until, copy badge on sub-bill tab, and voided sub-bill update',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final openTime = DateTime(2026, 11, 6, 16);
      final addTime = DateTime(2026, 11, 6, 16, 13);
      final repo = MockPosRepository.createFallback(now: addTime)
        ..update((s) {
          final pkg = s.packages.first.copyWith(timeLimit: 120);
          s.packages[0] = pkg;
          final tbl = s.tables.first; // t1 = A1
          final pm = s.payments.first;
          settle(
            s,
            tbl,
            TableTotals(a: 7),
            s.staff.first,
            timing: 'before',
            pkgId: pkg.id,
            method: pm,
            received: 7 * 199.0,
            billId: 'b1',
            now: openTime,
          );
          settle(
            s,
            tbl,
            TableTotals(a: 1),
            s.staff.first,
            timing: 'before',
            pkgId: pkg.id,
            method: pm,
            received: 199,
            billId: 'b2',
            now: addTime,
          );
        });

      await tester.pumpWidget(KepTohApp(repository: repo, now: addTime));
      await tester.pumpAndSettle();

      // Tap "สลิป POS" on table t1 -> opens TableSummaryModal
      final slipBtn = find.byKey(const ValueKey('table-slip-btn-t1'));
      expect(slipBtn, findsOneWidget);
      await tester.tap(slipBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('table-summary-modal')), findsOneWidget);
      expect(find.byKey(const ValueKey('table-summary-title')), findsOneWidget);
      expect(find.text('ใบสรุปยอดโต๊ะ (ไม่ใช่ใบกำกับภาษี)'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('table-summary-total')))
            .data,
        '฿1,592',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('summary-eat-until')))
            .data,
        'ทานได้ถึงเวลา 18:00 น. (จำกัด 2 ชม.)',
      );

      // Switch to sub-bill #2 tab -> ReceiptCard with "สำเนา" badge
      await tester.tap(find.text('บิล #2'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('receipt-copy-badge')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('receipt-eat-until')))
            .data,
        'ทานได้ถึงเวลา 18:00 น. (จำกัด 2 ชม.)',
      );

      // Void sub-bill #2 from TableSummaryModal
      await tester.tap(find.byKey(const ValueKey('receipt-void-btn')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('void-preset-คีย์จำนวนคนผิด')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-void-btn')));
      await tester.pumpAndSettle();

      // Summary now shows voided sub-bill #2 and net total ฿1,393
      expect(
        find.byKey(const ValueKey('summary-bill-voided-b2')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('table-summary-total')))
            .data,
        '฿1,393',
      );
      // Table t1 remains open for sub-bill #1
      expect(repo.state.openTables.containsKey('t1'), isTrue);
      expect(repo.state.openTables['t1']!.heads.a, 7);
    },
  );

  testWidgets(
    'Reprinted receipt from /bills shows "สำเนา" badge and eat-until time; '
    'overtime table on /tables shows table-overtime-<id>',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final openTime = DateTime(2026, 11, 6, 16);
      final lateTime = DateTime(2026, 11, 6, 18, 25); // 25 min overtime
      final repo = MockPosRepository.createFallback(now: lateTime)
        ..update((s) {
          final pkg = s.packages.first.copyWith(timeLimit: 120);
          s.packages[0] = pkg;
          settle(
            s,
            s.tables.first,
            TableTotals(a: 2),
            s.staff.first,
            timing: 'before',
            pkgId: pkg.id,
            method: s.payments.first,
            received: 398,
            billId: 'b1',
            now: openTime,
          );
        });

      // 1. Check /tables shows overtime label on t1
      await tester.pumpWidget(KepTohApp(repository: repo, now: lateTime));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('table-overtime-t1')), findsOneWidget);
      expect(find.textContaining('เกินเวลา 25 น.'), findsOneWidget);

      // 2. Navigate to /bills and re-open b1 -> shows "สำเนา" badge
      GoRouter.of(tester.element(find.byType(TablesPage))).go('/bills');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bill-row-no-b1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('receipt-copy-badge')), findsOneWidget);
      expect(find.text('สำเนา'), findsOneWidget);
    },
  );

  testWidgets(
    'ReportsPage displays partial fixed-cost pill and deducted vs full fixed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fixedNow = DateTime(2026, 11, 4, 12);
      final repo = _buildFullRepo(fixedNow: fixedNow)
        ..update((s) => s.shop = s.shop.copyWith(fixedCostDivisor: 'calendar'));
      await tester.pumpWidget(
        KepTohApp(repository: repo, now: fixedNow, initialLocation: '/reports'),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('reports-partial-fixed-pill')),
        findsOneWidget,
      );
      expect(find.text('หักค่าคงที่ยังไม่ครบเดือน'), findsOneWidget);
      expect(
        find.textContaining('รายวัน ฿720 · คงที่ ฿4,610 / ฿46,100'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'ตามปฏิทิน พฤศจิกายน 2569 (30 วัน) (ขายแล้ว 4 วัน)',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'TableLiveTimer renders countdown badge and Btn(loading: true) blocks taps',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final openTime = DateTime(2026, 11, 6, 16);
      final checkTime = DateTime(2026, 11, 6, 17, 25); // 35 min left
      final repo = MockPosRepository.createFallback(now: checkTime)
        ..update((s) {
          final pkg = s.packages.first.copyWith(timeLimit: 120);
          s.packages[0] = pkg;
          settle(
            s,
            s.tables.first,
            TableTotals(a: 2),
            s.staff.first,
            timing: 'before',
            pkgId: pkg.id,
            method: s.payments.first,
            received: 398,
            billId: 'b1',
            now: openTime,
          );
        });

      await tester.pumpWidget(KepTohApp(repository: repo, now: checkTime));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('table-countdown-t1')), findsOneWidget);
      expect(find.textContaining('เหลือ 35:00 · ถึง 18:00'), findsOneWidget);

      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Btn(
              key: const ValueKey('loading-btn'),
              label: 'กำลังบันทึก',
              loading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('loading-btn')));
      expect(taps, 0);
    },
  );
}
