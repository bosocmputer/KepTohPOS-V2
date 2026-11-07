import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner sign-in: LINE first, with email and password as the fallback.
class OwnerLoginForm extends StatefulWidget {
  const new({required this.session, required this.onSignedIn, super.key});

  final DeviceSession session;
  final VoidCallback onSignedIn;

  @override
  State<OwnerLoginForm> createState() => _OwnerLoginFormState();
}

class _OwnerLoginFormState extends State<OwnerLoginForm> {
  String _email = '';
  String _password = '';
  String _message = '';
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = _describe(e));
    } on Object {
      if (mounted) setState(() => _message = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _describe(AuthException e) => switch (e.code) {
    'invalid_credentials' => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
    'email_not_confirmed' => 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ',
    'user_already_exists' => 'อีเมลนี้มีบัญชีอยู่แล้ว',
    'weak_password' => 'รหัสผ่านสั้นเกินไป',
    _ => 'เข้าสู่ระบบไม่สำเร็จ',
  };

  Future<void> _signIn() => _run(() async {
    await widget.session.signInOwner(_email.trim(), _password);
    widget.onSignedIn();
  });

  Future<void> _signUp() => _run(() async {
    final ready = await widget.session.signUpOwner(_email.trim(), _password);
    if (ready) {
      widget.onSignedIn();
    } else if (mounted) {
      setState(
        () => _message = 'ส่งอีเมลยืนยันแล้ว กรุณายืนยันก่อนเข้าสู่ระบบ',
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final filled = _email.trim().isNotEmpty && _password.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Btn(
          key: const ValueKey('owner-line-btn'),
          label: 'เข้าสู่ระบบด้วย LINE',
          kind: BtnKind.primary,
          block: true,
          disabled: _busy,
          onPressed: () => _run(widget.session.signInOwnerWithLine),
        ),
        const SizedBox(height: AppDimensions.space4),
        Field(
          label: 'อีเมล',
          child: AppTextInput(
            key: const ValueKey('owner-email-input'),
            value: _email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) => setState(() => _email = v),
          ),
        ),
        const SizedBox(height: AppDimensions.space3),
        Field(
          label: 'รหัสผ่าน',
          child: AppTextInput(
            key: const ValueKey('owner-password-input'),
            value: _password,
            obscureText: true,
            onChanged: (v) => setState(() => _password = v),
          ),
        ),
        const SizedBox(height: AppDimensions.space3),
        Row(
          children: [
            Expanded(
              child: Btn(
                key: const ValueKey('owner-signin-btn'),
                label: 'เข้าสู่ระบบ',
                block: true,
                disabled: _busy || !filled,
                onPressed: _signIn,
              ),
            ),
            const SizedBox(width: AppDimensions.space2),
            Expanded(
              child: Btn(
                key: const ValueKey('owner-signup-btn'),
                label: 'สมัครบัญชีใหม่',
                block: true,
                disabled: _busy || !filled,
                onPressed: _signUp,
              ),
            ),
          ],
        ),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.space3),
          Text(
            _message,
            key: const ValueKey('owner-login-message'),
            style: TextStyle(color: t.dangerInk),
          ),
        ],
      ],
    );
  }
}
