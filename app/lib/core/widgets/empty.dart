import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';

/// Empty state placeholder (`Empty` in `prototype/index.html` & Figma).
class Empty extends StatelessWidget {
  const new({required this.title, super.key, this.text, this.action});

  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.space9,
        horizontal: AppDimensions.space4,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: tokens.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (text != null && text!.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.space2_5),
              Text(
                text!,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: tokens.muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppDimensions.space3),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Payment / action status screen (`ResultState` in `prototype/index.html`).
class ResultState extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.text,
    this.icon = 'check',
    this.isDanger = false,
  });

  final String title;
  final String? text;
  final String icon;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final mainColor = isDanger ? tokens.danger : tokens.success;
    final ringColor = isDanger ? tokens.dangerSoft : tokens.successSoft;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space4,
        AppDimensions.space4,
        AppDimensions.space4,
        AppDimensions.space5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppDimensions.btnLgH,
            height: AppDimensions.btnLgH,
            decoration: BoxDecoration(
              color: mainColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: ringColor, spreadRadius: AppDimensions.space2),
              ],
            ),
            child: Center(
              child: AppIcon(
                icon,
                size: AppDimensions.icon2xl,
                color: tokens.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(color: tokens.ink),
          ),
          if (text != null && text!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space2),
            Text(
              text!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
          ],
        ],
      ),
    );
  }
}
