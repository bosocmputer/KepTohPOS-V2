import 'dart:convert';
import 'dart:io';

import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/widgets/setup_shop_costing_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const ValueKey<String> _switchKey = ValueKey('setup-vat-registered-switch');
const ValueKey<String> _errKey = ValueKey('setup-vat-registered-error');

ShopConfig _shop({
  String vatMode = 'none',
  String taxId = '',
  bool registered = true,
}) => ShopConfig.fromJson({
  ...(jsonDecode(File('assets/mock/shop.json').readAsStringSync())
      as Map<String, dynamic>),
  'vatMode': vatMode,
  'taxId': taxId,
}).copyWith(vatRegistered: registered);

Future<List<ShopConfig>> _pump(
  WidgetTester tester,
  ShopConfig shop, {
  bool canEditVat = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1366, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final saved = <ShopConfig>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(brightness: Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SetupShopPanel(
            shop: shop,
            canEditVat: canEditVat,
            onSave: saved.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  testWidgets('owner sees the switch; manager does not', (tester) async {
    await _pump(tester, _shop());
    expect(find.byKey(_switchKey), findsOneWidget);
    expect(find.textContaining('ภ.พ.20'), findsOneWidget);
    await _pump(tester, _shop(), canEditVat: false);
    expect(find.byKey(_switchKey), findsNothing);
  });

  testWidgets('turning off is blocked while VAT mode is set', (tester) async {
    final saved = await _pump(tester, _shop(vatMode: 'exclusive'));
    await tester.tap(find.byKey(_switchKey));
    await tester.pumpAndSettle();
    expect(find.text("ตั้งโหมด VAT ของร้านเป็น 'ไม่มี VAT' ก่อน"), findsOne);
    await tester.tap(find.byKey(const ValueKey('setup-save-shop-btn')));
    expect(saved.single.vatRegistered, isTrue);
  });

  testWidgets('turning on is blocked without a 13-digit tax id', (
    tester,
  ) async {
    await _pump(tester, _shop(registered: false));
    await tester.tap(find.byKey(_switchKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_errKey), findsOneWidget);
  });

  testWidgets('turning off with VAT mode none is passed to onSave', (
    tester,
  ) async {
    final saved = await _pump(tester, _shop(taxId: '1234567890123'));
    await tester.tap(find.byKey(_switchKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_errKey), findsNothing);
    await tester.tap(find.byKey(const ValueKey('setup-save-shop-btn')));
    expect(saved.single.vatRegistered, isFalse);
  });

  testWidgets('turning on with a tax id is passed to onSave', (tester) async {
    final saved = await _pump(
      tester,
      _shop(taxId: '1234567890123', registered: false),
    );
    await tester.tap(find.byKey(_switchKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-save-shop-btn')));
    expect(saved.single.vatRegistered, isTrue);
  });
}
