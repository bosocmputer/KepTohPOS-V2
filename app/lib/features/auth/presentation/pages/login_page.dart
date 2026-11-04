import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/auth/presentation/widgets/login_hero_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/auth/presentation/widgets/login_hero_panel.dart';

/// PIN Login screen combining the Figma two-column layout (`design/figma/login.png`)
/// with the prototype content and ledger summary card (`function Login` in
/// `prototype/index.html`).
class LoginPage extends StatelessWidget {
  const new({super.key, this.onLoggedIn});

  final VoidCallback? onLoggedIn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (prev, curr) => !prev.isAuthenticated && curr.isAuthenticated,
      listener: (context, state) => onLoggedIn?.call(),
      builder: (context, state) {
        return Scaffold(
          backgroundColor: tokens.surface,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 860;
                if (isWide) {
                  return Padding(
                    padding: const EdgeInsets.all(AppDimensions.space5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: LoginHeroPanel(state: state)),
                        Expanded(
                          flex: 6,
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.space6,
                                vertical: AppDimensions.space4,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: _LoginFormPanel(state: state),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.space5),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LoginFormPanel(state: state),
                          const SizedBox(height: AppDimensions.space5),
                          LoginHeroPanel(state: state, compact: true),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LoginFormPanel extends StatelessWidget {
  const new({required this.state});

  final AuthState state;

  String _pinHintForRole(String role) {
    for (final s in state.staff) {
      if (s.role == role) return s.pin;
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<AuthCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Center(
          child: BrandLogo(
            size: AppDimensions.space12,
            radius: AppDimensions.radiusMd,
          ),
        ),
        const SizedBox(height: AppDimensions.space3),
        Text(
          'เข้าสู่ระบบ',
          textAlign: TextAlign.center,
          style: textTheme.displaySmall?.copyWith(color: tokens.ink),
        ),
        const SizedBox(height: AppDimensions.space1),
        Text(
          'เลือกชื่อของคุณ แล้วใส่ PIN 4 หลัก',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: tokens.muted),
        ),
        const SizedBox(height: AppDimensions.space5),
        Dropdown<String>(
          label: 'พนักงาน',
          value: state.selectedStaffId,
          options: state.staff
              .map(
                (x) => DropdownOption<String>(
                  value: x.id,
                  label: x.name,
                  sub: kRoles[x.role] ?? x.role,
                ),
              )
              .toList(),
          leadingBuilder: (o) => Avatar(name: o.label),
          onChanged: cubit.selectStaff,
        ),
        const SizedBox(height: AppDimensions.space3),
        PinDots(value: state.pin),
        if (state.error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space2),
            child: Text(
              state.error,
              key: const ValueKey('login-error'),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: tokens.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        NumPad(
          value: state.pin,
          maxLen: 4,
          onChanged: cubit.setPin,
          onEnter: cubit.submitPin,
        ),
        const SizedBox(height: AppDimensions.space4),
        Btn(
          key: const ValueKey('login-submit-btn'),
          label: state.hasOpenShift ? 'เข้าสู่ระบบ' : 'เข้าสู่ระบบและเปิดกะ',
          kind: BtnKind.primary,
          size: BtnSize.lg,
          block: true,
          disabled: state.selectedStaff == null,
          onPressed: cubit.submitPin,
        ),
        const SizedBox(height: AppDimensions.space3),
        Container(
          padding: const EdgeInsets.all(AppDimensions.space3),
          decoration: BoxDecoration(
            color: tokens.surface2,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Text(
            'PIN ตัวอย่าง: เจ้าของ ${_pinHintForRole("owner")} · '
            'ผู้จัดการ ${_pinHintForRole("manager")} · '
            'แคชเชียร์ ${_pinHintForRole("cashier")}',
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(color: tokens.muted),
          ),
        ),
      ],
    );
  }
}
