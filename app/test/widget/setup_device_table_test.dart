import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:app/features/setup/presentation/widgets/setup_device_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ShopDevice _device(String code, {String? rd, bool paired = true}) => ShopDevice(
  id: 'id-$code',
  code: code,
  name: 'แท็บเล็ต $code',
  paired: paired,
  revoked: false,
  isThisDevice: false,
  rdMachineCode: rd,
);

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.build(brightness: Brightness.light),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('device row shows RD status and both actions', (tester) async {
    // Arrange
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final revoked = <String>[];
    await tester.pumpWidget(
      _app(
        SetupDeviceTable(
          devices: [
            _device('A1', rd: 'E0001'),
            _device('B2', paired: false),
          ],
          busy: false,
          onEditRd: (_) {},
          onRevoke: (d) => revoked.add(d.code),
        ),
      ),
    );

    // Assert
    expect(find.text('เลขรหัส E0001'), findsOneWidget);
    expect(find.text('พิมพ์ได้แค่ใบเสร็จธรรมดา'), findsOneWidget);
    expect(find.text('แก้ไขเลขรหัส'), findsNWidgets(2));
    expect(find.text('ยกเลิกลิงก์'), findsOneWidget);

    // Act
    await tester.tap(find.byKey(const ValueKey('device-revoke-B2')));
    expect(revoked, ['B2']);
  });

  testWidgets('Confirm exposes yesKey and noKey on its buttons', (
    tester,
  ) async {
    // Arrange
    var yes = 0;
    await tester.pumpWidget(
      _app(
        Confirm(
          title: 't',
          text: 'x',
          yesKey: const ValueKey('device-revoke-confirm-btn'),
          onYes: () => yes++,
          onNo: () {},
        ),
      ),
    );

    // Act
    await tester.tap(find.byKey(const ValueKey('device-revoke-confirm-btn')));

    // Assert
    expect(yes, 1);
  });
}
