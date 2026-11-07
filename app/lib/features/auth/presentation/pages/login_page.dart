import 'dart:async';

import 'dart:math' as math;

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/auth/presentation/widgets/login_demo_pin_hint.dart';
import 'package:app/features/auth/presentation/widgets/login_hero_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/auth/presentation/widgets/login_hero_panel.dart';

/// Full-bleed PIN Login screen supporting Landscape Split-View (`>= 860px`),
/// Portrait Tablet (`768x1024`), and Mobile (`< 600px`) with iPhone-style
/// auto-submitting 4-digit PIN entry.
class LoginPage extends StatelessWidget {
  const new({super.key, this.onLoggedIn});

  final VoidCallback? onLoggedIn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (prev, curr) => !prev.isAuthenticated && curr.isAuthenticated,
      listener: (context, state) => onLoggedIn?.call(),
      builder: (context, state) => Scaffold(
        backgroundColor: tokens.surface,
        body: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 860
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: LoginHeroPanel(state: state)),
                    Expanded(
                      flex: 6,
                      child: SafeArea(
                        left: false,
                        child: _LoginViewport(state: state, isWide: true),
                      ),
                    ),
                  ],
                )
              : SafeArea(child: _LoginViewport(state: state, isWide: false)),
        ),
      ),
    );
  }
}

class _LoginViewport extends StatelessWidget {
  const new({required this.state, required this.isWide});

  final AuthState state;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = !isWide && constraints.maxWidth < 600;
        final isCompactH = constraints.maxHeight < 780;
        final compact = isMobile || constraints.maxHeight < 680;
        final hPad = isMobile ? AppDimensions.space4 : AppDimensions.space6;
        final vPad = isCompactH ? AppDimensions.space4 : AppDimensions.space6;
        final minH = math.max<double>(0, constraints.maxHeight - vPad * 2);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? 380 : 440,
                minHeight: minH,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox.shrink(),
                  _LoginFormPanel(
                    state: state,
                    compact: compact,
                    compactKeyHeight: !isMobile && isCompactH,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.space3),
                    child: _LoginFooter(
                      state: state,
                      showCompactLedger: !isWide,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoginFormPanel extends StatelessWidget {
  const new({
    required this.state,
    required this.compact,
    this.compactKeyHeight = false,
  });

  final AuthState state;
  final bool compact;
  final bool compactKeyHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<AuthCubit>();
    final tight = compact || compactKeyHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Center(
          child: BrandLogo(
            size: AppDimensions.avatarLg,
            radius: AppDimensions.radiusMd,
          ),
        ),
        SizedBox(height: tight ? AppDimensions.space2 : AppDimensions.space3),
        Text(
          'เข้าสู่ระบบ',
          textAlign: TextAlign.center,
          style: textTheme.displayMedium?.copyWith(color: tokens.ink),
        ),
        const SizedBox(height: AppDimensions.space1),
        Text(
          'เลือกชื่อของคุณ แล้วใส่ PIN 4 หลัก',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: tokens.muted),
        ),
        SizedBox(height: tight ? AppDimensions.space3 : AppDimensions.space5),
        Text(
          'พนักงาน',
          style: textTheme.labelMedium?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppDimensions.space1_5),
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
        SizedBox(height: tight ? AppDimensions.space2_5 : AppDimensions.space4),
        PinDots(
          value: state.pin,
          hasError: state.error.isNotEmpty,
          boxSize: compact ? 48 : 54,
          gap: compact ? AppDimensions.space3 : AppDimensions.space4,
        ),
        if (state.error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space3,
                  vertical: AppDimensions.space1_5,
                ),
                decoration: BoxDecoration(
                  color: tokens.dangerSoft,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon('alert', size: 18, color: tokens.dangerInk),
                    const SizedBox(width: AppDimensions.space1_5),
                    Text(
                      state.error,
                      key: const ValueKey('login-error'),
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.dangerInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        NumPad(
          value: state.pin,
          maxLen: 4,
          maxWidth: double.infinity,
          filledKeys: true,
          keyboard: true,
          showClear: true,
          keyHeight: compact ? 52 : (compactKeyHeight ? 54 : 60),
          rowGap: tight ? AppDimensions.space2 : AppDimensions.space3,
          colGap: compact ? AppDimensions.space2 : AppDimensions.space3,
          onChanged: (v) {
            cubit.setPin(v);
            if (v.length == 4) unawaited(cubit.submitPin(v));
          },
          onEnter: cubit.submitPin,
        ),
      ],
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const new({required this.state, required this.showCompactLedger});

  final AuthState state;
  final bool showCompactLedger;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final last = state.lastClosedDay;
    final heroV = state.heroProfitValue;
    final isGain = heroV >= 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCompactLedger && last != null) ...[
          Container(
            key: const ValueKey('login-compact-ledger-banner'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space4,
              vertical: AppDimensions.space3,
            ),
            decoration: BoxDecoration(
              color: tokens.primarySoft,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: tokens.primarySoft2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ปิดยอดล่าสุด · ${thDateShort(last.date)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${isGain ? "กำไร" : "ขาดทุน"} ${baht(heroV.abs())}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: isGain ? tokens.successInk : tokens.dangerInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space2),
        ],
        if (state.isDemoData) LoginDemoPinHint(state: state),
      ],
    );
  }
}
