import 'package:app/core/data/local/connection_monitor.dart';
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
    expect(find.text('ออฟไลน์ · ตรวจการเชื่อมต่ออินเทอร์เน็ต'), findsOneWidget);

    // Act & Assert
    status.value = const SyncStatus(online: false, pending: 2);
    await tester.pump();
    expect(
      find.text('ออฟไลน์ · รอส่ง 2 รายการเมื่อเน็ตกลับมา'),
      findsOneWidget,
    );

    status.value = const SyncStatus(online: true, pending: 2);
    await tester.pump();
    expect(find.text('กำลังส่งข้อมูลที่ค้าง 2 รายการ'), findsOneWidget);

    status.value = const SyncStatus(online: true, pending: 0);
    await tester.pump();
    expect(banner, findsNothing);
  });
}
