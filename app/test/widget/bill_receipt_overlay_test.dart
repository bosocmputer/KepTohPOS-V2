import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/bills/presentation/cubit/bills_cubit.dart';
import 'package:app/features/bills/presentation/widgets/reissue_bill_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 9, 12);

  Future<void> pump(WidgetTester tester, {required bool fullInvoice}) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = MockPosRepository.createFallback(now: now)
      ..update((s) {
        final pkg = s.packages.first;
        makeBill(
          s,
          id: 'b1',
          at: now.toUtc().toIso8601String(),
          tableId: 't1',
          staffId: s.staff.first.id,
          packageId: pkg.id,
          order: calcOrder(s.shop, pkg, 2, 0, 0, const <AddonLineInput>[]),
          method: s.payments.first,
          received: 50000,
        );
      });
    final cubit = BillsCubit(repo, now: now);
    addTearDown(cubit.close);
    final base = repo.state.sales.firstWhere((b) => b.id == 'b1');
    final bill = BillRecord.fromJson(<String, dynamic>{
      ...base.toJson(),
      'isFullInvoice': fullInvoice,
    });
    final owner = repo.state.staff.firstWhere((s) => s.role == 'owner');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                billReceiptOverlay(context, cubit, bill, owner),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reissue button shows for a normal bill', (tester) async {
    await pump(tester, fullInvoice: false);
    expect(find.byKey(const ValueKey('receipt-reissue-btn')), findsOneWidget);
  });

  testWidgets('reissue button is hidden for a full tax invoice', (
    tester,
  ) async {
    await pump(tester, fullInvoice: true);
    expect(find.byKey(const ValueKey('receipt-reissue-btn')), findsNothing);
  });
}
