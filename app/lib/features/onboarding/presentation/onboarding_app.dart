import 'dart:async';

import 'package:app/app.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:app/features/onboarding/presentation/owner_login_form.dart';
import 'package:app/features/onboarding/presentation/owner_shop_step.dart';
import 'package:flutter/material.dart';

enum _Step { loading, failed, choose, code, ownerLogin, ownerShop }

/// First screen in Supabase mode: restores the device or pairs it to a shop,
/// then hands over to [KepTohApp].
class OnboardingApp extends StatefulWidget {
  const new({super.key});

  @override
  State<OnboardingApp> createState() => _OnboardingAppState();
}

class _OnboardingAppState extends State<OnboardingApp> {
  DeviceSession? _session;
  _Step _step = _Step.loading;
  String _code = '';
  String _error = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    setState(() => _step = _Step.loading);
    try {
      final session = _session ??= await DeviceSession.start();
      final shopId = await session.pairedShopId();
      if (shopId != null) {
        await _enter(shopId);
        return;
      }
      if (mounted) {
        setState(() {
          _step = session.isOwnerSignedIn ? _Step.ownerShop : _Step.choose;
        });
      }
    } on Object {
      if (mounted) setState(() => _step = _Step.failed);
    }
  }

  Future<void> _enter(String shopId) async {
    final session = _session!;
    final repo = await session.openRepository(shopId);
    await configureDependencies(repository: repo, deviceSession: session);
    runApp(const KepTohApp());
  }

  Future<void> _claim() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await _enter(await _session!.claim(_code.trim()));
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'รหัสจับคู่ไม่ถูกต้องหรือหมดอายุแล้ว';
        });
      }
    }
  }

  Widget _body(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final session = _session;
    return switch (_step) {
      _Step.loading => const Center(child: CircularProgressIndicator()),
      _Step.failed => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต',
            style: TextStyle(color: t.dangerInk),
          ),
          const SizedBox(height: AppDimensions.space3),
          Btn(
            key: const ValueKey('boot-retry-btn'),
            label: 'ลองใหม่',
            block: true,
            onPressed: _boot,
          ),
        ],
      ),
      _Step.choose => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('เริ่มใช้งานเครื่องนี้', style: tt.titleLarge),
          const SizedBox(height: AppDimensions.space4),
          Btn(
            key: const ValueKey('choose-owner-btn'),
            label: 'ฉันเป็นเจ้าของร้าน',
            kind: BtnKind.primary,
            block: true,
            onPressed: () => setState(() => _step = _Step.ownerLogin),
          ),
          const SizedBox(height: AppDimensions.space2),
          Btn(
            key: const ValueKey('choose-code-btn'),
            label: 'มีรหัสจับคู่เครื่องแล้ว',
            block: true,
            onPressed: () => setState(() => _step = _Step.code),
          ),
        ],
      ),
      _Step.code => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(
            label: 'รหัสจับคู่เครื่อง',
            child: AppTextInput(
              key: const ValueKey('pairing-code-input'),
              value: _code,
              onChanged: (v) => setState(() => _code = v),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space2),
            Text(_error, style: TextStyle(color: t.dangerInk)),
          ],
          const SizedBox(height: AppDimensions.space3),
          Btn(
            key: const ValueKey('pairing-submit-btn'),
            label: 'จับคู่เครื่อง',
            kind: BtnKind.primary,
            block: true,
            disabled: _busy || _code.trim().isEmpty,
            onPressed: _claim,
          ),
          const SizedBox(height: AppDimensions.space2),
          Btn(
            label: 'ย้อนกลับ',
            block: true,
            onPressed: () => setState(() => _step = _Step.choose),
          ),
        ],
      ),
      _Step.ownerLogin => OwnerLoginForm(
        session: session!,
        onSignedIn: () => setState(() => _step = _Step.ownerShop),
      ),
      _Step.ownerShop => OwnerShopStep(
        session: session!,
        onPaired: (shopId) => unawaited(_enter(shopId)),
      ),
    };
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'KepToh POS',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(brightness: Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        backgroundColor: context.tokens.surface,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _body(context),
            ),
          ),
        ),
      ),
    ),
  );
}
