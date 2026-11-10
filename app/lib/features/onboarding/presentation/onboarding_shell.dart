import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Page frame for the first screens, matching the staff PIN screen: the
/// orange brand panel on wide screens, the form alone on phones.
class OnboardingShell extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final form = SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  wide ? AppDimensions.space8 : AppDimensions.space4,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: child,
                ),
              ),
            ),
          );
          if (!wide) return form;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(flex: 5, child: _OnboardingHero()),
              Expanded(flex: 6, child: form),
            ],
          );
        },
      ),
    );
  }
}

class _OnboardingHero extends StatelessWidget {
  const new();

  static const List<String> _points = <String>[
    'เข้าด้วย LINE ได้ ไม่ต้องจำรหัสผ่าน',
    'ใช้แท็บเล็ต มือถือ หรือคอมพิวเตอร์ที่มีอยู่ได้เลย',
    'พนักงานเข้าด้วย PIN 4 หลัก ไม่ต้องมีบัญชี',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final onHero = t.onPrimary;
    return ColoredBox(
      color: t.primary,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandLogoName(),
            const Spacer(),
            Text(
              'เปิดร้านบนเครื่องนี้\nเสร็จในไม่กี่ขั้นตอน',
              style: tt.displayLarge?.copyWith(color: onHero, height: 1.25),
            ),
            const SizedBox(height: AppDimensions.space5),
            for (final p in _points)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.space2),
                child: Row(
                  children: [
                    AppIcon('check', color: onHero),
                    const SizedBox(width: AppDimensions.space2),
                    Expanded(
                      child: Text(
                        p,
                        style: tt.bodyMedium?.copyWith(color: onHero),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Logo, title and one line of help at the top of each first-screen step.
class OnboardingHeader extends StatelessWidget {
  const new({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space5),
      child: Column(
        children: [
          const BrandLogo(
            size: AppDimensions.avatarLg,
            radius: AppDimensions.radiusMd,
          ),
          const SizedBox(height: AppDimensions.space3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tt.displayMedium?.copyWith(color: t.ink),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppDimensions.space1),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: t.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// A large tappable choice with an icon, a title and what it is for.
class OnboardingChoiceCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  final String icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.space4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppDimensions.avatarLg / 2,
                backgroundColor: t.primarySoft,
                child: AppIcon(icon, color: t.primary),
              ),
              const SizedBox(width: AppDimensions.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: tt.titleMedium?.copyWith(color: t.ink)),
                    const SizedBox(height: AppDimensions.spaceHalf),
                    Text(
                      description,
                      style: tt.bodySmall?.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              AppIcon('forward', color: t.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Branded loading card matching the HTML boot loader during setup & load.
class OnboardingLoadingCard extends StatelessWidget {
  const new({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space6),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: t.line),
        boxShadow: t.shadows,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.space2_5),
            decoration: BoxDecoration(
              color: t.primarySoft,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: const BrandLogo(
              size: AppDimensions.avatarLg,
              radius: AppDimensions.radiusMd,
            ),
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tt.displayMedium?.copyWith(color: t.ink),
          ),
          const SizedBox(height: AppDimensions.space1_5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: t.muted),
          ),
          const SizedBox(height: AppDimensions.space5),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            child: SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                minHeight: 5,
                color: t.primary,
                backgroundColor: t.primarySoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
