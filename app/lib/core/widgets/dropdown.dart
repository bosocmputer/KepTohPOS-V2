import 'dart:math' as math;

import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';

/// Option item for [Dropdown] (`{ value, label, sub }` in `index.html`).
class DropdownOption<T> {
  const new({required this.value, required this.label, this.sub});

  final T value;
  final String label;
  final String? sub;
}

/// Custom floating dropdown selector (`Dropdown` in `prototype/index.html` &
/// Figma). Uses [OverlayPortal] + [CompositedTransformFollower] so opening the
/// menu never shifts surrounding layout elements.
class Dropdown<T> extends StatefulWidget {
  const new({
    required this.options,
    required this.onChanged,
    super.key,
    this.value,
    this.label,
    this.placeholder = 'เลือก',
    this.leadingBuilder,
  });

  final T? value;
  final List<DropdownOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? label;
  final String placeholder;
  final Widget Function(DropdownOption<T> option)? leadingBuilder;

  @override
  State<Dropdown<T>> createState() => _DropdownState<T>();
}

class _DropdownState<T> extends State<Dropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _portalController = OverlayPortalController();
  final GlobalKey _triggerKey = GlobalKey();
  Size _triggerSize = Size.zero;
  Offset _triggerOffset = Offset.zero;

  bool get _open => _portalController.isShowing;

  DropdownOption<T>? get _selected =>
      widget.options.where((o) => o.value == widget.value).firstOrNull;

  void _toggleMenu() {
    if (_open) return _closeMenu();
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      _triggerSize = box.size;
      _triggerOffset = box.localToGlobal(Offset.zero);
    }
    setState(_portalController.show);
  }

  void _closeMenu() {
    if (_open) setState(_portalController.hide);
  }

  Widget _buildOptionContent(
    BuildContext context,
    DropdownOption<T> opt, {
    bool inlineSub = false,
  }) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final hasSub = opt.sub != null && opt.sub!.isNotEmpty;
    final labelStyle = tt.bodyMedium?.copyWith(
      color: t.ink,
      fontWeight: FontWeight.w600,
    );
    final subStyle = tt.labelSmall?.copyWith(
      color: t.muted,
      fontSize: AppDimensions.fsXs,
    );
    if (inlineSub && widget.leadingBuilder == null) {
      return Row(
        children: [
          Flexible(child: Text(opt.label, maxLines: 1, style: labelStyle)),
          if (hasSub) ...[
            Text(' · ', style: subStyle),
            Text(opt.sub!, maxLines: 1, style: subStyle),
          ],
        ],
      );
    }
    return Row(
      children: [
        if (widget.leadingBuilder != null) ...[
          widget.leadingBuilder!(opt),
          const SizedBox(width: AppDimensions.space3),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(opt.label, maxLines: 1, style: labelStyle),
              if (hasSub) Text(opt.sub!, maxLines: 1, style: subStyle),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverlayMenu(BuildContext context) {
    final tokens = context.tokens;
    final mq = MediaQuery.of(context);
    final estHeight = math.min(
      AppDimensions.dropdownMaxListH,
      widget.options.length * 56.0 + AppDimensions.space2,
    );
    final spaceBelow =
        mq.size.height -
        mq.padding.bottom -
        (_triggerOffset.dy + _triggerSize.height);
    final spaceAbove = _triggerOffset.dy - mq.padding.top;
    final openUpward = spaceBelow < estHeight && spaceAbove > spaceBelow;
    final maxH = math.min<double>(
      AppDimensions.dropdownMaxListH,
      math.max<double>(120, (openUpward ? spaceAbove : spaceBelow) - 8),
    );
    final menuWidth = _triggerSize.width > 0 ? _triggerSize.width : 200.0;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('dropdown-backdrop'),
            behavior: HitTestBehavior.translucent,
            onTap: _closeMenu,
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: openUpward ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: openUpward ? Alignment.bottomLeft : Alignment.topLeft,
          offset: Offset(
            0,
            openUpward ? -AppDimensions.space1 : AppDimensions.space1,
          ),
          child: SizedBox(
            width: menuWidth,
            child: Container(
              constraints: BoxConstraints(maxHeight: maxH),
              padding: const EdgeInsets.all(AppDimensions.space1),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: tokens.line),
                boxShadow: tokens.shadows,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.options.map((opt) {
                    final isSelected = opt.value == widget.value;
                    return Material(
                      color: isSelected
                          ? tokens.primarySoft
                          : tokens.surface.withValues(alpha: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? tokens.primary
                              : tokens.line.withValues(alpha: 0),
                          width: AppDimensions.borderThick,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          _closeMenu();
                          widget.onChanged(opt.value);
                        },
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppDimensions.dropdownMinH,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.space3,
                              vertical: AppDimensions.space2,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildOptionContent(context, opt),
                                ),
                                if (isSelected)
                                  AppIcon(
                                    'check',
                                    size: AppDimensions.iconSm,
                                    color: tokens.primaryInk,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final selected = _selected;
    final hasLeading = widget.leadingBuilder != null;
    const radius = AppDimensions.radiusMd;

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: _buildOverlayMenu,
        child: Material(
          key: _triggerKey,
          color: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
              color: _open ? tokens.primary : tokens.line,
              width: AppDimensions.borderThick,
            ),
          ),
          child: InkWell(
            onTap: _toggleMenu,
            borderRadius: BorderRadius.circular(radius),
            child: ConstrainedBox(
              constraints: hasLeading
                  ? const BoxConstraints(minHeight: AppDimensions.tap)
                  : const BoxConstraints.tightFor(height: AppDimensions.tap),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.space3,
                  vertical: hasLeading ? AppDimensions.space2 : 0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: selected != null
                          ? _buildOptionContent(
                              context,
                              selected,
                              inlineSub: !hasLeading,
                            )
                          : Text(
                              widget.placeholder,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: tokens.muted),
                            ),
                    ),
                    const SizedBox(width: AppDimensions.space2),
                    AppIcon(
                      'chevron',
                      size: AppDimensions.iconSm,
                      color: tokens.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
