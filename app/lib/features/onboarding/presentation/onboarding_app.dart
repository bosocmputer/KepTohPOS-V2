import 'dart:async';

import 'package:app/app.dart';
import 'package:app/core/data/local/local_db.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:app/features/onboarding/data/sync_setup.dart';
import 'package:app/features/onboarding/presentation/onboarding_shell.dart';
import 'package:app/features/onboarding/presentation/owner_login_form.dart';
import 'package:app/features/onboarding/presentation/owner_shop_step.dart';
import 'package:flutter/material.dart';

enum _Step { loading, failed, choose, code, ownerLogin, ownerShop }

/// First screen in Supabase mode: restores the device or pairs it to a shop,
/// then hands over to [KepTohApp].
class OnboardingApp extends StatefulWidget {
  const new({super.key, this.session});

  /// An already started session, when the app comes back here after the
  /// device leaves its shop.
  final DeviceSession? session;

  @override
  State<OnboardingApp> createState() => _OnboardingAppState();
}

class _OnboardingAppState extends State<OnboardingApp> {
  late DeviceSession? _session = widget.session;
  _Step _step = _Step.loading;
  String _code = '';
  bool _codeFromLink = false;
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
        // A link sent from setup (?pair=CODE) goes straight to pairing; a
        // failed LINE or Google sign-in comes back with ?error=...
        final query = Uri.base.queryParameters;
        final pair = query['pair']?.trim() ?? '';
        setState(() {
          if (pair.isNotEmpty) {
            _code = pair;
            _codeFromLink = true;
            _step = _Step.code;
          } else {
            _step = session.isOwnerSignedIn ? _Step.ownerShop : _Step.choose;
          }
          if (query.containsKey('error')) {
            _error = 'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่';
          }
        });
      }
    } on Object {
      // No connection: open the shop as last saved on this device, if any.
      if (await _enterOffline()) return;
      if (mounted) setState(() => _step = _Step.failed);
    }
  }

  Future<bool> _enterOffline() async {
    final session = _session;
    if (session == null) return false;
    final db = LocalDb();
    final repo = await restoreOffline(session, db);
    if (repo == null) {
      await db.close();
      return false;
    }
    await configureDependencies(repository: repo, deviceSession: session);
    final sync = startSync(session, repo, db: db);
    runApp(KepTohApp(busy: session.busy, sync: sync.status));
    return true;
  }

  Future<void> _enter(String shopId) async {
    final session = _session!;
    final repo = await session.openRepository(shopId);
    await configureDependencies(repository: repo, deviceSession: session);
    final sync = startSync(session, repo);
    runApp(KepTohApp(busy: session.busy, sync: sync.status));
  }

  Future<void> _signOutOwner() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await _session!.signOutOwner();
      if (mounted) setState(() => _step = _Step.choose);
    } on Object {
      if (mounted) setState(() => _error = 'ออกจากระบบไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  void _go(_Step step) => setState(() {
    _error = '';
    _step = step;
  });

  Widget _errorText(AppTokens t) => Padding(
    padding: const EdgeInsets.only(top: AppDimensions.space3),
    child: Text(
      _error,
      key: const ValueKey('onboarding-error'),
      textAlign: TextAlign.center,
      style: TextStyle(color: t.dangerInk),
    ),
  );

  Widget _backLink(_Step to) => Padding(
    padding: const EdgeInsets.only(top: AppDimensions.space3),
    child: Btn(
      key: const ValueKey('onboarding-back-btn'),
      label: 'ย้อนกลับ',
      kind: BtnKind.ghost,
      block: true,
      onPressed: () => _go(to),
    ),
  );

  Widget _body(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final session = _session;
    final children = switch (_step) {
      _Step.loading => <Widget>[
        const OnboardingHeader(title: 'กำลังเปิดแอป…'),
        const Center(child: CircularProgressIndicator()),
      ],
      _Step.failed => <Widget>[
        const OnboardingHeader(
          title: 'เชื่อมต่อไม่ได้',
          subtitle: 'ตรวจสอบอินเทอร์เน็ตของเครื่องนี้ แล้วลองใหม่',
        ),
        Btn(
          key: const ValueKey('boot-retry-btn'),
          label: 'ลองใหม่',
          kind: BtnKind.primary,
          block: true,
          onPressed: _boot,
        ),
      ],
      _Step.choose => <Widget>[
        const OnboardingHeader(
          title: 'เริ่มใช้งานเครื่องนี้',
          subtitle: 'เลือกว่าเครื่องนี้จะเข้าร้านด้วยวิธีไหน',
        ),
        OnboardingChoiceCard(
          key: const ValueKey('choose-owner-btn'),
          icon: 'user',
          title: 'ฉันเป็นเจ้าของร้าน',
          description: 'สร้างร้านใหม่ หรือใช้เครื่องนี้กับร้านของฉัน',
          onTap: () => _go(_Step.ownerLogin),
        ),
        const SizedBox(height: AppDimensions.space3),
        OnboardingChoiceCard(
          key: const ValueKey('choose-code-btn'),
          icon: 'qr',
          title: 'ได้ลิงก์หรือรหัสจากเจ้าของร้าน',
          description: 'แท็บเล็ตเครื่องที่ 2 หรือมือถือผู้จัดการ/พนักงาน',
          onTap: () => _go(_Step.code),
        ),
        if (_error.isNotEmpty) _errorText(t),
      ],
      _Step.code => <Widget>[
        OnboardingHeader(
          title: _codeFromLink ? 'ได้รับลิงก์เข้าร้านแล้ว' : 'ใส่รหัสเข้าร้าน',
          subtitle: _codeFromLink
              ? 'กดปุ่มด้านล่างเพื่อเชื่อมเครื่องนี้กับร้าน'
              : 'ขอรหัสจากเจ้าของร้าน: ตั้งค่า › เครื่องและลิงก์เข้าร้าน',
        ),
        Field(
          label: 'รหัสเข้าร้าน',
          child: AppTextInput(
            key: const ValueKey('pairing-code-input'),
            value: _code,
            onChanged: (v) => setState(() => _code = v),
          ),
        ),
        const SizedBox(height: AppDimensions.space3),
        Btn(
          key: const ValueKey('pairing-submit-btn'),
          label: 'เชื่อมเครื่องนี้กับร้าน',
          kind: BtnKind.primary,
          block: true,
          disabled: _busy || _code.trim().isEmpty,
          onPressed: _claim,
        ),
        if (_error.isNotEmpty) _errorText(t),
        _backLink(_Step.choose),
      ],
      _Step.ownerLogin => <Widget>[
        const OnboardingHeader(
          title: 'เข้าสู่ระบบเจ้าของร้าน',
          subtitle: 'แนะนำ LINE ไม่ต้องจำรหัสผ่าน',
        ),
        OwnerLoginForm(
          session: session!,
          onSignedIn: () => _go(_Step.ownerShop),
        ),
        _backLink(_Step.choose),
      ],
      _Step.ownerShop => <Widget>[
        OwnerShopStep(
          session: session!,
          onPaired: (shopId) => unawaited(_enter(shopId)),
        ),
        const SizedBox(height: AppDimensions.space5),
        Divider(color: t.line, height: 1),
        const SizedBox(height: AppDimensions.space3),
        if (session.ownerEmail case final email?)
          Text(
            'เข้าสู่ระบบอยู่: $email',
            key: const ValueKey('onboarding-owner-email'),
            style: tt.bodySmall?.copyWith(color: t.muted),
            textAlign: TextAlign.center,
          ),
        Btn(
          key: const ValueKey('onboarding-signout-btn'),
          label: 'ออกจากระบบ / เปลี่ยนบัญชี',
          kind: BtnKind.ghost,
          block: true,
          disabled: _busy,
          onPressed: _signOutOwner,
        ),
        if (_error.isNotEmpty) _errorText(t),
      ],
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'KepToh POS',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(brightness: Brightness.light),
    builder: (context, child) {
      final busy = _session?.busy;
      final page = child ?? const SizedBox.shrink();
      return busy == null ? page : BusyOverlay(busy: busy, child: page);
    },
    home: Builder(builder: (context) => OnboardingShell(child: _body(context))),
  );
}
