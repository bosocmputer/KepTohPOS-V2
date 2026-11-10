import 'package:app/core/di/injection.dart';
import 'package:app/core/sync/sync_widgets.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:app/features/onboarding/presentation/onboarding_app.dart';
import 'package:flutter/material.dart';

/// Owner-only "leave the shop on this device": unpairs this device and goes
/// back to the first screen, e.g. to sign in with another account.
class SetupDeviceLeaveSection extends StatefulWidget {
  const new({required this.session, super.key});

  final DeviceSession session;

  @override
  State<SetupDeviceLeaveSection> createState() =>
      _SetupDeviceLeaveSectionState();
}

class _SetupDeviceLeaveSectionState extends State<SetupDeviceLeaveSection> {
  bool _busy = false;
  String _error = '';

  Future<void> _leave() async {
    // Leaving now would strand bills that have not reached the server.
    final clear = await confirmWithPendingSync(
      context,
      action: 'ออกจากร้าน',
      block: true,
    );
    if (!clear || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Confirm(
        title: 'ออกจากร้านบนเครื่องนี้?',
        text:
            'เครื่องนี้จะกลับไปหน้าเริ่มต้น ข้อมูลร้านไม่หาย '
            'ถ้าจะใช้เครื่องนี้กับร้านนี้อีก ให้เข้าสู่ระบบเจ้าของร้านใหม่',
        yesLabel: 'ออกจากร้าน',
        danger: true,
        yesKey: const ValueKey('device-leave-confirm-btn'),
        onYes: () => Navigator.pop(context, true),
        onNo: () => Navigator.pop(context, false),
      ),
    );
    if (!(ok ?? false)) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.session.leaveShop();
      await sl.reset();
      runApp(OnboardingApp(session: widget.session));
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'ออกจากร้านไม่สำเร็จ กรุณาลองใหม่';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: AppDimensions.space6),
        Text('เครื่องนี้', style: tt.titleSmall),
        const SizedBox(height: AppDimensions.space1),
        Text(
          'ใช้เมื่อจะเปลี่ยนไปใช้ร้านอื่น หรือเข้าด้วยบัญชีเจ้าของอื่น',
          style: tt.bodySmall?.copyWith(color: t.muted),
        ),
        const SizedBox(height: AppDimensions.space2),
        Align(
          alignment: Alignment.centerLeft,
          child: Btn(
            key: const ValueKey('device-leave-btn'),
            label: 'ออกจากร้านบนเครื่องนี้',
            disabled: _busy,
            onPressed: _leave,
          ),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.space2),
          Text(_error, style: TextStyle(color: t.dangerInk)),
        ],
      ],
    );
  }
}
