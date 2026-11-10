import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner sign-in: LINE first, then Google.
class OwnerLoginForm extends StatefulWidget {
  const new({required this.session, required this.onSignedIn, super.key});

  final DeviceSession session;
  final VoidCallback onSignedIn;

  @override
  State<OwnerLoginForm> createState() => _OwnerLoginFormState();
}

class _OwnerLoginFormState extends State<OwnerLoginForm> {
  String _message = '';
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await action();
    } on AuthException {
      if (mounted) setState(() => _message = 'เข้าสู่ระบบไม่สำเร็จ');
    } on Object {
      if (mounted) setState(() => _message = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: AppDimensions.btnLgH,
          child: FilledButton(
            key: const ValueKey('owner-line-btn'),
            style: FilledButton.styleFrom(
              backgroundColor: AppRawTokens.lineGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              textStyle: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            onPressed: _busy
                ? null
                : () => _run(widget.session.signInOwnerWithLine),
            child: const Text('เข้าสู่ระบบด้วย LINE'),
          ),
        ),
        const SizedBox(height: AppDimensions.space2),
        Btn(
          key: const ValueKey('owner-google-btn'),
          label: 'เข้าสู่ระบบด้วย Google',
          size: BtnSize.lg,
          block: true,
          disabled: _busy,
          onPressed: () => _run(widget.session.signInOwnerWithGoogle),
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
