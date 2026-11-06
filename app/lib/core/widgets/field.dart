import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Labeled form field wrapper (`Field` in `prototype/index.html` & Figma).
class Field extends StatelessWidget {
  const new({required this.label, required this.child, super.key, this.hint});

  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: tokens.muted,
              fontSize: AppDimensions.fsSm,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.space1_5),
        ],
        child,
        if (hint != null && hint!.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.space1_5),
          Text(
            hint!,
            style: textTheme.labelSmall?.copyWith(
              color: tokens.muted,
              fontSize: AppDimensions.fsXs,
            ),
          ),
        ],
      ],
    );
  }
}

/// Token-styled single- or multi-line text input (`input` in `index.html`).
class AppTextInput extends StatefulWidget {
  const new({
    super.key,
    this.value = '',
    this.onChanged,
    this.placeholder = '',
    this.suffixText,
    this.maxLines = 1,
    this.keyboardType,
    this.readOnly = false,
  });

  final String value;
  final ValueChanged<String>? onChanged;
  final String placeholder;
  final String? suffixText;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool readOnly;

  @override
  State<AppTextInput> createState() => _AppTextInputState();
}

class _AppTextInputState extends State<AppTextInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant AppTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tt = Theme.of(context).textTheme;
    final isSingleLine = widget.maxLines == 1;
    final hasSuffix =
        widget.suffixText != null && widget.suffixText!.isNotEmpty;

    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(
          color: _focusNode.hasFocus ? tokens.primary : tokens.line,
          width: AppDimensions.borderThick,
        ),
      ),
      child: ConstrainedBox(
        constraints: isSingleLine
            ? const BoxConstraints.tightFor(height: AppDimensions.tap)
            : const BoxConstraints(minHeight: AppDimensions.tap),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.space3,
            vertical: isSingleLine ? 0 : AppDimensions.space2_5,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: widget.onChanged,
                  maxLines: widget.maxLines,
                  keyboardType: widget.keyboardType,
                  readOnly: widget.readOnly,
                  textAlignVertical: isSingleLine
                      ? TextAlignVertical.center
                      : null,
                  style: tt.bodyMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    border: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                    constraints: isSingleLine
                        ? const BoxConstraints.tightFor(
                            height: AppDimensions.tap,
                          )
                        : null,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isSingleLine ? 12 : 0,
                    ),
                    hintText: widget.placeholder,
                    hintStyle: tt.bodyMedium?.copyWith(color: tokens.muted),
                  ),
                ),
              ),
              if (hasSuffix) ...[
                const SizedBox(width: AppDimensions.space1_5),
                Text(
                  widget.suffixText!,
                  style: tt.labelSmall?.copyWith(
                    color: tokens.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
