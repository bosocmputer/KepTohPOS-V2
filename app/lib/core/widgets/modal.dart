import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/btn.dart';
import 'package:flutter/material.dart';

/// Shared modal dialog card (`Modal` in `prototype/index.html` & Figma).
class Modal extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    super.key,
    this.sub,
    this.onClose,
    this.footer = const <Widget>[],
    this.wide = false,
  });

  final String title;
  final String? sub;
  final VoidCallback? onClose;
  final Widget child;
  final List<Widget> footer;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final maxWidth = wide ? AppDimensions.modalWideW : AppDimensions.modalW;
    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeight = screenH * AppDimensions.modalMaxHeightFactor;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: tokens.line),
            boxShadow: tokens.shadows,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.space5,
                  AppDimensions.space3_5,
                  AppDimensions.space4,
                  AppDimensions.space3_5,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: tokens.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: textTheme.headlineMedium?.copyWith(
                              color: tokens.ink,
                            ),
                          ),
                          if (sub != null && sub!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spaceHalf),
                            Text(
                              sub!,
                              style: textTheme.bodySmall?.copyWith(
                                color: tokens.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onClose != null)
                      Btn(
                        kind: BtnKind.ghost,
                        icon: 'x',
                        semanticLabel: 'ปิด',
                        onPressed: onClose,
                      ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.space5),
                  child: child,
                ),
              ),
              if (footer.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space5,
                    vertical: AppDimensions.space3,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surface2,
                    border: Border(top: BorderSide(color: tokens.line)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppDimensions.space2_5,
                    runSpacing: AppDimensions.space2,
                    children: footer,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
