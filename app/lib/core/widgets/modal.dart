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
    this.footerLeading,
    this.footer = const <Widget>[],
    this.wide = false,
  });

  final String title;
  final String? sub;
  final VoidCallback? onClose;
  final Widget child;
  final Widget? footerLeading;
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
              if (footer.isNotEmpty || footerLeading != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space5,
                    vertical: AppDimensions.space3,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surface2,
                    border: Border(top: BorderSide(color: tokens.line)),
                  ),
                  child: footerLeading != null
                      ? Row(
                          children: [
                            Expanded(child: footerLeading!),
                            const SizedBox(width: AppDimensions.space3),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: AppDimensions.space2_5,
                              runSpacing: AppDimensions.space2,
                              children: footer,
                            ),
                          ],
                        )
                      : Wrap(
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

/// Mounts [child] full-screen on the root [Overlay] (covering the Topbar
/// with `100%` viewport height, equivalent to `position: fixed; inset: 0`),
/// while preserving its position in the logical widget tree.
class RootOverlayBox extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<RootOverlayBox> createState() => _RootOverlayBoxState();
}

class _RootOverlayBoxState extends State<RootOverlayBox> {
  final OverlayPortalController _controller = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _controller.show();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _controller,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (_) => Positioned.fill(child: widget.child),
    );
  }
}

/// Shared right-side slide-over drawer (`340px` wide, `100%` screen height
/// over the Topbar with dark scrim and `SafeArea`) used by `BillsFilterDrawer`
/// and the Stock filter drawer.
class RightSheetDrawer extends StatelessWidget {
  const new({
    required this.title,
    required this.onClose,
    required this.child,
    super.key,
    this.drawerKey,
    this.closeButtonKey,
    this.closeSemanticLabel = 'ปิดตัวกรอง',
    this.footer,
    this.width = AppDimensions.rightDrawerW,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final Key? drawerKey;
  final Key? closeButtonKey;
  final String closeSemanticLabel;
  final Widget? footer;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;

    return RootOverlayBox(
      child: Material(
        key: drawerKey,
        color: t.scrim,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: width,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(left: BorderSide(color: t.line)),
                  boxShadow: t.shadows,
                ),
                child: SafeArea(
                  left: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space5,
                          vertical: AppDimensions.space3_5,
                        ),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: t.line)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: tt.titleLarge?.copyWith(
                                  color: t.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Btn(
                              key: closeButtonKey,
                              kind: BtnKind.ghost,
                              icon: 'x',
                              semanticLabel: closeSemanticLabel,
                              onPressed: onClose,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppDimensions.space5),
                          child: child,
                        ),
                      ),
                      if (footer != null)
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.space5),
                          decoration: BoxDecoration(
                            color: t.surface2,
                            border: Border(top: BorderSide(color: t.line)),
                          ),
                          child: footer,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
