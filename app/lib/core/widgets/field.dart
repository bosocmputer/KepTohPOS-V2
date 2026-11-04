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
    this.maxLines = 1,
    this.keyboardType,
    this.readOnly = false,
  });

  final String value;
  final ValueChanged<String>? onChanged;
  final String placeholder;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool readOnly;

  @override
  State<AppTextInput> createState() => _AppTextInputState();
}

class _AppTextInputState extends State<AppTextInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      borderSide: BorderSide(
        color: tokens.line,
        width: AppDimensions.borderThick,
      ),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      borderSide: BorderSide(
        color: tokens.primary,
        width: AppDimensions.borderThick,
      ),
    );

    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      readOnly: widget.readOnly,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: tokens.ink),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: tokens.surface,
        hintText: widget.placeholder,
        hintStyle: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: tokens.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space3,
          vertical: AppDimensions.space2_5,
        ),
        enabledBorder: border,
        focusedBorder: focusedBorder,
        border: border,
      ),
    );
  }
}
