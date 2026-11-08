import 'dart:async';
import 'dart:convert';

import 'package:app/core/data/local/connection_monitor.dart';
import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/data/local/outbox_queue.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/sync/sync_center.dart';
import 'package:app/core/sync/sync_describe.dart';
import 'package:app/core/sync/sync_status_sheet.dart';
import 'package:app/core/sync/sync_widgets.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 8, 19);
  late LocalDb db;
  late StreamController<List<OutboxEntry>> rows;
  late SyncCenter center;
  late int sends;
  late PosState shop;

  OutboxEntry entry(
    String id,
    String fn,
    Map<String, dynamic> params, {
    DateTime? at,
    bool rejected = false,
    String? error,
  }) => OutboxEntry(
    seq: id.hashCode,
    id: id,
    shopId: 's1',
    fn: fn,
    params: jsonEncode(params),
    createdAt: at ?? DateTime(2026, 11, 8, 18, 27),
    attempts: 0,
    lastError: error,
    rejected: rejected,
  );

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
    rows = StreamController<List<OutboxEntry>>.broadcast();
    sends = 0;
    final repo = MockPosRepository.createFallback(now: now);
    shop = repo.state.copy()
      ..sales.add(
        BillRecord(
          id: 'b4',
          no: '000004',
          date: '2026-11-08',
          at: '2026-11-08T11:27:00Z',
          tableId: 't1',
          tableName: 'A1',
          staffId: 'st1',
          staffName: 'อัย',
          packageId: 'pk1',
          lines: const <OrderLineItem>[],
          subtotal: 79800,
          service: 0,
          vat: 0,
          rounding: 0,
          total: 79800,
          heads: HeadsCount(a: 2),
          methodId: 'pm1',
          methodName: 'เงินสด',
          methodType: 'cash',
          received: 80000,
          change: 200,
        ),
      );
    center = SyncCenter(
      queue: OutboxQueue(db, shopId: 's1'),
      monitor: ConnectionMonitor(
        reachable: ValueNotifier<bool>(true),
        hasNetwork: const Stream<bool>.empty(),
        pendingCount: const Stream<int>.empty(),
      ),
      sendNow: () async => sends++,
      shop: () => shop,
      entries: rows.stream,
    );
    sl.registerSingleton<SyncCenter>(center);
  });

  tearDown(() async {
    await sl.reset();
    center.dispose();
    await rows.close();
    await db.close();
  });

  Future<void> emit(List<OutboxEntry> v) async {
    rows.add(v);
    await Future<void>.delayed(Duration.zero);
  }

  test('names a waiting bill the way a cashier reads it', () {
    final e = entry('b4', 'settle_bill', {'p_bill_id': 'b4'});
    expect(
      describeEntry(e, shop, now),
      'คิดเงิน · บิล 000004 · โต๊ะ A1 · ฿798 · 18:27',
    );
  });

  test('explains a refusal in Thai with what to do', () {
    final (why, todo) = refusalReason(
      'PostgrestException(message: no open shift, code: P0001)',
    );
    expect(why, 'ไม่มีกะที่เปิดอยู่ตอนส่ง');
    expect(todo, contains('เปิดกะ'));
    expect(refusalReason(null).$1, 'ระบบไม่รับรายการนี้');
  });

  test('marks bills waiting or refused, and data older than 3 days', () async {
    // Arrange
    final old = now.subtract(const Duration(days: 4));

    // Act
    await emit([
      entry('b4', 'settle_bill', {'p_bill_id': 'b4'}, at: old),
      entry('v1', 'void_bill', {'p_bill_id': 'b9'}, rejected: true),
      entry('r1', 'send_round', {'p_table_id': 't1'}),
    ]);

    // Assert
    expect(center.bills, {'b4': BillSync.waiting, 'b9': BillSync.refused});
    expect(center.isStale(now), isTrue);
    expect(center.isStale(old.add(const Duration(days: 2))), isFalse);
  });

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(brightness: Brightness.light),
      home: Scaffold(body: child),
    ),
  );

  testWidgets('sheet lists what waits and why one was refused', (tester) async {
    // Arrange
    await pump(tester, SyncStatusSheet(center: center, now: () => now));
    await tester.runAsync(
      () => emit([
        entry(
          'b4',
          'settle_bill',
          {'p_bill_id': 'b4'},
          rejected: true,
          error: 'staff session is invalid or expired',
        ),
        entry('r1', 'send_round', {
          'p_table_id': 't1',
        }, at: now.subtract(const Duration(days: 4))),
      ]),
    );
    await tester.pump();

    // Assert
    expect(find.text('ส่งไม่ผ่าน 1 รายการ'), findsOneWidget);
    expect(find.text('รอส่ง 1 รายการ'), findsOneWidget);
    expect(
      find.text('คิดเงิน · บิล 000004 · โต๊ะ A1 · ฿798 · 18:27'),
      findsOneWidget,
    );
    expect(
      find.text('สาเหตุ: การเข้าสู่ระบบของพนักงานหมดอายุ'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sync-stale-warning')), findsOneWidget);

    // Act
    await tester.tap(find.byKey(const ValueKey('sync-send-now-btn')));
    await tester.pump();

    // Assert
    expect(sends, 1);
  });

  testWidgets('sheet says all sent when nothing waits', (tester) async {
    await pump(tester, SyncStatusSheet(center: center, now: () => now));
    expect(find.byKey(const ValueKey('sync-all-sent')), findsOneWidget);
  });

  testWidgets('badge shows only on a bill that has not reached the server', (
    tester,
  ) async {
    // Arrange
    await pump(
      tester,
      const Column(
        children: [
          BillSyncBadge(billId: 'b4'),
          BillSyncBadge(billId: 'b1'),
        ],
      ),
    );

    // Act
    await tester.runAsync(
      () => emit([
        entry('b4', 'settle_bill', {'p_bill_id': 'b4'}),
      ]),
    );
    await tester.pump();

    // Assert
    expect(find.text('⏳ รอส่ง'), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-sync-b1')), findsNothing);
  });

  testWidgets('leaving the shop is blocked while data waits', (tester) async {
    // Arrange
    bool? result;
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await confirmWithPendingSync(
            context,
            action: 'ออกจากร้าน',
            block: true,
          ),
          child: const Text('leave'),
        ),
      ),
    );
    await tester.runAsync(
      () => emit([
        entry('b4', 'settle_bill', {'p_bill_id': 'b4'}),
      ]),
    );

    // Act
    await tester.tap(find.text('leave'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('ยังออกจากร้านไม่ได้'), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-guard-continue-btn')), findsNothing);
    await tester.tap(find.text('ปิด'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('logging out with data waiting asks first, then allows', (
    tester,
  ) async {
    // Arrange
    bool? result;
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await confirmWithPendingSync(
            context,
            action: 'ออกจากระบบ',
          ),
          child: const Text('logout'),
        ),
      ),
    );
    await tester.runAsync(
      () => emit([
        entry('r1', 'send_round', {'p_table_id': 't1'}),
      ]),
    );

    // Act
    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sync-guard-continue-btn')));
    await tester.pumpAndSettle();

    // Assert
    expect(result, isTrue);
  });
}
