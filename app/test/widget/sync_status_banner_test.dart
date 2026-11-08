import 'package:app/core/data/local/connection_monitor.dart';
import 'package:app/core/data/local/outbox_queue.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ValueNotifier<SyncStatus>> pump(
    WidgetTester tester,
    SyncStatus start,
  ) async {
    final status = ValueNotifier<SyncStatus>(start);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light),
        home: SyncStatusBanner(
          status: status,
          child: const Scaffold(body: Text('page')),
        ),
      ),
    );
    return status;
  }

  final banner = find.byKey(const ValueKey('sync-status-banner'));

  testWidgets('hidden when online with nothing waiting', (tester) async {
    await pump(tester, const SyncStatus(online: true, pending: 0));
    expect(banner, findsNothing);
    expect(find.text('page'), findsOneWidget);
  });

  testWidgets('says offline, then how much waits, then hides', (tester) async {
    // Arrange
    final status = await pump(
      tester,
      const SyncStatus(online: false, pending: 0),
    );
    expect(
      find.text('ออฟไลน์ · ขายต่อได้ ข้อมูลจะส่งเมื่อเน็ตกลับมา'),
      findsOneWidget,
    );

    // Act & Assert
    status.value = const SyncStatus(online: false, pending: 2);
    await tester.pump();
    expect(find.text('ออฟไลน์ · ขายต่อได้ · รอส่ง 2 รายการ'), findsOneWidget);

    status.value = const SyncStatus(online: true, pending: 2);
    await tester.pump();
    expect(find.text('กำลังส่งข้อมูลที่ค้าง 2 รายการ'), findsOneWidget);

    status.value = const SyncStatus(online: true, pending: 0);
    await tester.pump();
    expect(banner, findsNothing);
  });

  testWidgets('counts bills offline, shows progress, then a green done', (
    tester,
  ) async {
    // Arrange
    final status = await pump(
      tester,
      const SyncStatus(online: false, pending: 5, pendingBills: 2),
    );
    expect(
      find.text('ออฟไลน์ · ขายต่อได้ · รอส่ง 5 รายการ (บิล 2 ใบ)'),
      findsOneWidget,
    );

    // Act & Assert: sending.
    status.value = const SyncStatus(
      online: true,
      pending: 2,
      pendingBills: 1,
      progress: OutboxProgress(total: 5, bills: 2, sent: 3, sentBills: 1),
    );
    await tester.pump();
    expect(find.text('กำลังส่ง 3/5 รายการ · บิล 1/2 ใบ'), findsOneWidget);

    // Act & Assert: done.
    status.value = const SyncStatus(
      online: true,
      pending: 0,
      progress: OutboxProgress(
        total: 5,
        bills: 2,
        sent: 5,
        sentBills: 2,
        done: true,
      ),
    );
    await tester.pump();
    expect(find.text('ส่งครบแล้ว 5 รายการ · บิล 2 ใบ'), findsOneWidget);
    expect(SyncStatusBanner.toneFor(status.value).name, 'good');
  });

  testWidgets('a refused command is called out', (tester) async {
    await pump(
      tester,
      const SyncStatus(
        online: true,
        pending: 0,
        progress: OutboxProgress(
          total: 3,
          bills: 1,
          sent: 2,
          sentBills: 1,
          rejected: 1,
          done: true,
        ),
      ),
    );
    expect(
      find.text('ส่งแล้ว 2 รายการ · ไม่ผ่าน 1 รายการ ให้ผู้จัดการตรวจสอบ'),
      findsOneWidget,
    );
  });
}
