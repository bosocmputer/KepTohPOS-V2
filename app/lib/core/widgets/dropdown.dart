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

/// Custom dropdown selector (`Dropdown` in `prototype/index.html` & Figma).
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
  bool _open = false;

  DropdownOption<T>? get _selected {
    for (final opt in widget.options) {
      if (opt.value == widget.value) return opt;
    }
    return null;
  }

  Widget _buildOptionContent(BuildContext context, DropdownOption<T> opt) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
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
              Text(
                opt.label,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (opt.sub != null && opt.sub!.isNotEmpty)
                Text(
                  opt.sub!,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.muted,
                    fontSize: AppDimensions.fsXs,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final selected = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            side: BorderSide(
              color: _open ? tokens.primary : tokens.line,
              width: AppDimensions.borderThick,
            ),
          ),
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
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
                      child: selected != null
                          ? _buildOptionContent(context, selected)
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
        if (_open) ...[
          const SizedBox(height: AppDimensions.space1),
          Container(
            constraints: const BoxConstraints(
              maxHeight: AppDimensions.dropdownMaxListH,
            ),
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
                        setState(() => _open = false);
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
        ],
      ],
    );
  }
}
