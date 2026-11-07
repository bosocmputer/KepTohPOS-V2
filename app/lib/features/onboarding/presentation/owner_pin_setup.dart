import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Sets a 4-digit PIN with the login keypad, entered twice like on a phone,
/// so a mistyped PIN cannot lock the owner out of the device.
class OwnerPinSetup extends StatefulWidget {
  const new({
    required this.onConfirmed,
    required this.onBack,
    super.key,
    this.busy = false,
  });

  final ValueChanged<String> onConfirmed;
  final VoidCallback onBack;
  final bool busy;

  @override
  State<OwnerPinSetup> createState() => _OwnerPinSetupState();
}

class _OwnerPinSetupState extends State<OwnerPinSetup> {
  static const int _length = 4;

  String _first = '';
  String _value = '';
  bool _confirming = false;
  bool _mismatch = false;

  @override
  void didUpdateWidget(covariant OwnerPinSetup oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Still here after the request ended means it failed: start over.
    if (oldWidget.busy && !widget.busy) {
      _first = '';
      _value = '';
      _confirming = false;
    }
  }

  void _onChanged(String v) {
    if (widget.busy) return;
    setState(() {
      _value = v;
      if (v.isNotEmpty) _mismatch = false;
    });
    if (v.length < _length) return;
    if (!_confirming) {
      setState(() {
        _first = v;
        _value = '';
        _confirming = true;
      });
    } else if (v == _first) {
      widget.onConfirmed(v);
    } else {
      setState(() {
        _first = '';
        _value = '';
        _confirming = false;
        _mismatch = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _confirming
              ? 'ยืนยัน PIN อีกครั้ง'
              : 'ตั้ง PIN 4 หลักสำหรับเข้าใช้งานเครื่อง',
          key: const ValueKey('owner-pin-title'),
          textAlign: TextAlign.center,
          style: tt.titleMedium?.copyWith(
            color: t.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppDimensions.space2),
        Text(
          _mismatch ? 'PIN ไม่ตรงกัน ลองตั้งใหม่อีกครั้ง' : ' ',
          key: const ValueKey('owner-pin-message'),
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: t.dangerInk),
        ),
        const SizedBox(height: AppDimensions.space3),
        PinDots(value: _value, hasError: _mismatch),
        const SizedBox(height: AppDimensions.space4),
        if (widget.busy) const PinCheckingHint(label: 'กำลังสร้างร้าน…'),
        NumPad(
          key: const ValueKey('owner-pin-pad'),
          value: _value,
          maxLen: _length,
          maxWidth: double.infinity,
          filledKeys: true,
          keyboard: true,
          showClear: true,
          onChanged: _onChanged,
        ),
        const SizedBox(height: AppDimensions.space3),
        Btn(
          key: const ValueKey('owner-pin-back-btn'),
          label: 'ย้อนกลับไปแก้ชื่อร้าน',
          block: true,
          disabled: widget.busy,
          onPressed: widget.onBack,
        ),
      ],
    );
  }
}
