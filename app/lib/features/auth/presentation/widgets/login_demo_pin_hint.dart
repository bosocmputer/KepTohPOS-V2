import 'package:app/core/theme/tokens.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter/material.dart';

/// Shows the sample PINs. Only used with demo data, where PINs are not secret.
class LoginDemoPinHint extends StatelessWidget {
  const new({required this.state, super.key});

  final AuthState state;

  String _pinOf(String role) =>
      state.staff.where((s) => s.role == role).firstOrNull?.pin ?? '-';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space3),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(
        'PIN ตัวอย่าง: เจ้าของ ${_pinOf("owner")} · '
        'ผู้จัดการ ${_pinOf("manager")} · '
        'แคชเชียร์ ${_pinOf("cashier")}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: tokens.muted),
      ),
    );
  }
}
