import 'package:app/app.dart';
import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/bills/presentation/pages/bills_page.dart';
import 'package:app/features/tables/presentation/pages/tables_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

MockPosRepository _buildRepoWithBills(DateTime fixedNow) {
  return MockPosRepository.createFallback(now: fixedNow)..update((s) {
    final pkg = s.packages.first;
    final pmCash = s.payments.first;
    final order1 = calcOrder(s.shop, pkg, 2, 0, 0, <AddonLineInput>[
      AddonLineInput(addon: s.addons.first, qty: 2),
    ]);
    final order2 = calcOrder(s.shop, pkg, 1, 0, 0, const <AddonLineInput>[]);
    settle(
      s,
      s.tables.first,
      TableTotals(a: 2, ad: {'ad1': 2}),
      s.staff.first,
      timing: 'before',
      pkgId: pkg.id,
      method: pmCash,
      received: order1.total,
      billId: 'b1',
      now: fixedNow.subtract(const Duration(minutes: 10)),
    );
    settle(
      s,
      s.tables.first,
      TableTotals(a: 1),
      s.staff.first,
      timing: 'before',
      pkgId: pkg.id,
      method: pmCash,
      received: order2.total,
      billId: 'b2',
      now: fixedNow,
    );
  });
}

void main() {
  final fixedNow = DateTime(2026, 11, 4, 18);

  testWidgets('tap bill row -> open receipt -> void bill with reason -> '
      'row shows "ยกเลิก" and summary sales decreases', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _buildRepoWithBills(fixedNow);

    // b1 = 428, b2 = 199 -> initial totalSales = 627, stock ad1 = 94
    expect(repo.state.addons.first.stock, 94);

    await tester.pumpWidget(
      KepTohApp(repository: repo, now: fixedNow, initialLocation: '/bills'),
    );
    await tester.pumpAndSettle();

    final statsGroup = find.byKey(const ValueKey('bills-stats-group'));

    // Verify initial summary sales is ฿627 and 2 bills
    expect(
      find.descendant(of: statsGroup, matching: find.text('฿627')),
      findsOneWidget,
    );
    expect(find.text('ไม่มีบิลยกเลิก'), findsOneWidget);

    // 1. Tap row for b1 (261104-001, ฿428.00) -> opens ReceiptModal
    await tester.tap(find.byKey(const ValueKey('bill-row-no-b1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-modal')), findsOneWidget);

    // 2. Tap "ยกเลิกบิล" button -> shows void confirmation form
    final voidBtn = find.byKey(const ValueKey('receipt-void-btn'));
    expect(voidBtn, findsOneWidget);
    await tester.tap(voidBtn);
    await tester.pumpAndSettle();

    // 3. Enter reason and confirm void
    final reasonField = find.descendant(
      of: find.byKey(const ValueKey('void-reason-input')),
      matching: find.byType(TextField),
    );
    await tester.enterText(reasonField, 'คีย์จำนวนคนผิด');
    await tester.pumpAndSettle();

    final confirmBtn = find.byKey(const ValueKey('confirm-void-btn'));
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // 4. Close ReceiptModal
    await tester.tap(find.byKey(const ValueKey('receipt-done-btn')));
    await tester.pumpAndSettle();

    // 5. Row shows "ยกเลิก" pill, summary sales is ฿199, stock returned to 96
    expect(find.text('ยกเลิก'), findsWidgets);
    expect(find.text('ยกเลิก 1 บิล'), findsOneWidget);
    expect(
      find.descendant(of: statsGroup, matching: find.text('฿199')),
      findsOneWidget,
    );
    expect(repo.state.addons.first.stock, 96);
  });

  testWidgets('void bill -> toast appears -> pump 3s -> toast disappears '
      'and BillsCubit.toastMessage is empty', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _buildRepoWithBills(DateTime(2026, 11, 4, 18));
    await tester.pumpWidget(
      KepTohApp(repository: repo, now: fixedNow, initialLocation: '/bills'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bill-row-no-b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('receipt-void-btn')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('void-reason-input')),
        matching: find.byType(TextField),
      ),
      'คีย์จำนวนคนผิด',
    );
    await tester.pump();
    final confirmBtn = find.byKey(const ValueKey('confirm-void-btn'));
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pump();

    // Toast is visible and BillsCubit.state.toastMessage is immediately cleared
    expect(find.byKey(const ValueKey('active-app-toast')), findsOneWidget);
    expect(find.textContaining('ยกเลิกบิล'), findsWidgets);
    final pageCtx = tester.element(find.byType(BillsPage));
    expect(pageCtx.read<BillsCubit>().state.toastMessage, isEmpty);

    // Pump 3 seconds -> toast auto-dismisses
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byKey(const ValueKey('active-app-toast')), findsNothing);
    expect(pageCtx.read<BillsCubit>().state.toastMessage, isEmpty);
  });

  testWidgets('void bill -> navigate to /tables and back to /bills -> '
      'no stale toast reappears', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _buildRepoWithBills(DateTime(2026, 11, 4, 18));
    await tester.pumpWidget(
      KepTohApp(repository: repo, now: fixedNow, initialLocation: '/bills'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bill-row-no-b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('receipt-void-btn')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('void-reason-input')),
        matching: find.byType(TextField),
      ),
      'คีย์จำนวนคนผิด',
    );
    await tester.pump();
    final confirmBtn = find.byKey(const ValueKey('confirm-void-btn'));
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pump();

    // Dismiss modal & wait for toast to auto-dismiss
    await tester.tap(find.byKey(const ValueKey('receipt-done-btn')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-app-toast')), findsNothing);

    // Navigate to /tables and back to /bills
    final ctx = tester.element(find.byType(BillsPage));
    GoRouter.of(ctx).go('/tables');
    await tester.pumpAndSettle();
    expect(find.byType(TablesPage), findsOneWidget);

    final tablesCtx = tester.element(find.byType(TablesPage));
    GoRouter.of(tablesCtx).go('/bills');
    await tester.pumpAndSettle();
    expect(find.byType(BillsPage), findsOneWidget);

    // No stale toast reappears
    expect(find.byKey(const ValueKey('active-app-toast')), findsNothing);
  });

  testWidgets('open filter drawer + trigger toast -> '
      '"ล้างตัวกรอง" button remains tappable', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _buildRepoWithBills(DateTime(2026, 11, 4, 18));
    await tester.pumpWidget(
      KepTohApp(repository: repo, now: fixedNow, initialLocation: '/bills'),
    );
    await tester.pumpAndSettle();

    // Open filter drawer and verify it spans full screen height (0..768)
    await tester.tap(find.byKey(const ValueKey('bills-filter-btn')));
    await tester.pumpAndSettle();
    final drawerFinder = find.byKey(const ValueKey('bills-filter-drawer'));
    expect(drawerFinder, findsOneWidget);
    expect(tester.getTopLeft(drawerFinder).dy, 0);
    expect(tester.getSize(drawerFinder).height, 768);

    await tester.tap(find.byKey(const ValueKey('filter-method-pm1')));
    await tester.pumpAndSettle();
    final pageCtx = tester.element(find.byType(BillsPage));
    expect(pageCtx.read<BillsCubit>().state.activeFilterCount, 1);

    // Trigger a toast while filter drawer is open
    showAppToast(pageCtx, 'แจ้งเตือนทดสอบขณะเปิดตัวกรอง');
    await tester.pump();
    expect(find.byKey(const ValueKey('active-app-toast')), findsOneWidget);

    // Tap "ล้างตัวกรอง" -> must not be blocked by toast
    await tester.tap(find.byKey(const ValueKey('filter-clear-btn')));
    await tester.pump();
    expect(pageCtx.read<BillsCubit>().state.activeFilterCount, 0);
  });

  testWidgets('portrait tablet (820x1180) renders 2-row Topbar on /bills '
      'with visible title and zero overflow', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _buildRepoWithBills(DateTime(2026, 11, 4, 18));
    await tester.pumpWidget(
      KepTohApp(repository: repo, now: fixedNow, initialLocation: '/bills'),
    );
    await tester.pumpAndSettle();

    expect(find.text('บิลขาย'), findsOneWidget);
    expect(tester.getSize(find.text('บิลขาย')).width, greaterThan(40));
    expect(find.byKey(const ValueKey('bills-date-dropdown')), findsOneWidget);
    expect(find.byKey(const ValueKey('bills-filter-btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('shell-user-btn')), findsOneWidget);
  });
}
