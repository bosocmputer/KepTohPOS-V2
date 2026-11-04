import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter/material.dart';

/// Left-hand orange hero panel on `LoginPage` showing the latest closed day
/// profit/loss summary from `computeLedger(s)` (`function Login` in
/// `prototype/index.html` & `design/figma/login.png`).
class LoginHeroPanel extends StatelessWidget {
  const new({required this.state, super.key, this.compact = false});

  final AuthState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final last = state.lastClosedDay;
    final heroV = state.heroProfitValue;
    final isGain = heroV >= 0;

    return Container(
      key: const ValueKey('login-hero-panel'),
      padding: EdgeInsets.all(
        compact ? AppDimensions.space5 : AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: tokens.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(
            children: [
              Container(
                width: AppDimensions.avatarSm,
                height: AppDimensions.avatarSm,
                decoration: BoxDecoration(
                  color: tokens.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Center(child: AppIcon('flame', color: tokens.onPrimary)),
              ),
              const SizedBox(width: AppDimensions.space3),
              Text(
                'KepToh POS',
                style: textTheme.displaySmall?.copyWith(
                  color: tokens.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space5),
          Text(
            'วันนี้ขายบุฟเฟต์\nได้กำไรหรือขาดทุน?',
            style: textTheme.displayLarge?.copyWith(
              color: tokens.onPrimary,
              height: 1.25,
            ),
          ),
          if (!compact) const Spacer() else const SizedBox(height: 20),
          if (last != null)
            Container(
              key: const ValueKey('login-hero-ledger-card'),
              padding: const EdgeInsets.all(AppDimensions.space5),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ตัวอย่างปิดยอดล่าสุด · ${thDateShort(last.date)}',
                    style: textTheme.labelSmall?.copyWith(
                      color: tokens.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space1_5),
                  Text(
                    '${isGain ? "กำไร" : "ขาดทุน"} ${baht(heroV.abs())}',
                    style: textTheme.displayMedium?.copyWith(
                      color: isGain ? tokens.success : tokens.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space3),
                  _HeroMetricRow('ยอดขาย (ก่อน VAT)', baht(last.net)),
                  const SizedBox(height: AppDimensions.space1_5),
                  _HeroMetricRow('ต้นทุนวัตถุดิบ', baht(last.ingCost)),
                  const SizedBox(height: AppDimensions.space1_5),
                  _HeroMetricRow(
                    'Food cost',
                    last.foodPct != null ? '${fmt(last.foodPct, 1)}%' : '–',
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            'ต้นแบบสำหรับทดลองกด · ข้อมูลทั้งหมดเป็นข้อมูลจำลอง',
            style: textTheme.bodySmall?.copyWith(
              color: tokens.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetricRow extends StatelessWidget {
  const new(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodySmall?.copyWith(color: tokens.muted)),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
