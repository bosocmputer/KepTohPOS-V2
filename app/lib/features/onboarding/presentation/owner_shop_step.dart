import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:app/features/onboarding/presentation/owner_pin_setup.dart';
import 'package:flutter/material.dart';

/// After the owner signs in: use an existing shop or create the first one.
class OwnerShopStep extends StatefulWidget {
  const new({required this.session, required this.onPaired, super.key});

  final DeviceSession session;
  final ValueChanged<String> onPaired;

  @override
  State<OwnerShopStep> createState() => _OwnerShopStepState();
}

class _OwnerShopStepState extends State<OwnerShopStep> {
  late final Future<List<OwnedShop>> _shops = widget.session.ownerShops();
  String _shopName = '';
  String _ownerName = '';
  bool _settingPin = false;
  String _error = '';
  bool _busy = false;
  String? _createdShopId;

  bool get _canContinue =>
      _shopName.trim().isNotEmpty && _ownerName.trim().isNotEmpty;

  Future<void> _pair(Future<String> Function() shopId) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final id = await shopId();
      await widget.session.pairThisDevice(id, 'เครื่องแคชเชียร์');
      widget.onPaired(id);
    } on Object {
      if (mounted) setState(() => _error = 'ทำรายการไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _createForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Field(
        label: 'ชื่อร้าน',
        child: AppTextInput(
          key: const ValueKey('shop-name-input'),
          value: _shopName,
          onChanged: (v) => setState(() => _shopName = v),
        ),
      ),
      const SizedBox(height: AppDimensions.space3),
      Field(
        label: 'ชื่อเจ้าของร้าน',
        child: AppTextInput(
          key: const ValueKey('owner-name-input'),
          value: _ownerName,
          onChanged: (v) => setState(() => _ownerName = v),
        ),
      ),
      const SizedBox(height: AppDimensions.space4),
      Btn(
        key: const ValueKey('shop-next-btn'),
        label: 'ถัดไป: ตั้ง PIN',
        kind: BtnKind.primary,
        block: true,
        disabled: _busy || !_canContinue,
        onPressed: () => setState(() {
          _settingPin = true;
          _error = '';
        }),
      ),
    ],
  );

  Widget _pinStep() => OwnerPinSetup(
    busy: _busy,
    onBack: () => setState(() => _settingPin = false),
    onConfirmed: (pin) => _pair(
      // Reuse the shop if pairing failed last time; retrying must not
      // create a second organization.
      () async => _createdShopId ??= await widget.session.createShop(
        shopName: _shopName.trim(),
        ownerName: _ownerName.trim(),
        pin: pin,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FutureBuilder<List<OwnedShop>>(
      future: _shops,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text(
            'โหลดข้อมูลร้านไม่ได้ กรุณาลองใหม่',
            style: TextStyle(color: t.dangerInk),
          );
        }
        final shops = snapshot.data ?? const <OwnedShop>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shops.isEmpty && _settingPin)
              _pinStep()
            else if (shops.isEmpty)
              _createForm()
            else
              for (final shop in shops)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space2),
                  child: Btn(
                    key: ValueKey('use-shop-${shop.id}'),
                    label: 'ใช้เครื่องนี้กับ ${shop.name}',
                    block: true,
                    disabled: _busy,
                    onPressed: () => _pair(() async => shop.id),
                  ),
                ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.space3),
              Text(_error, style: TextStyle(color: t.dangerInk)),
            ],
          ],
        );
      },
    );
  }
}
