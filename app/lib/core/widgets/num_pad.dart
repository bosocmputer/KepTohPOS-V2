import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Numeric keypad (`NumPad` in `prototype/index.html` & Figma Login).
class NumPad extends StatefulWidget {
  const new({
    required this.value,
    required this.onChanged,
    super.key,
    this.maxLen = 12,
    this.decimal = false,
    this.keyboard = false,
    this.keyHeight = AppDimensions.numPadKeyH,
    this.rowGap = AppDimensions.space2,
    this.onEnter,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int maxLen;
  final bool decimal;
  final bool keyboard;
  final double keyHeight;
  final double rowGap;
  final ValueChanged<String>? onEnter;

  @override
  State<NumPad> createState() => _NumPadState();
}

class _NumPadState extends State<NumPad> {
  late String _current;

  @override
  void initState() {
    super.initState();
    _current = widget.value;
    if (widget.keyboard) {
      HardwareKeyboard.instance.addHandler(_onKeyEvent);
    }
  }

  @override
  void didUpdateWidget(covariant NumPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    _current = widget.value;
    if (oldWidget.keyboard != widget.keyboard) {
      if (widget.keyboard) {
        HardwareKeyboard.instance.addHandler(_onKeyEvent);
      } else {
        HardwareKeyboard.instance.removeHandler(_onKeyEvent);
      }
    }
  }

  @override
  void dispose() {
    if (widget.keyboard) {
      HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    }
    super.dispose();
  }

  void _push(String digit) {
    if (digit == '.' && (!widget.decimal || _current.contains('.'))) return;
    if (_current.length >= widget.maxLen) return;
    final next = (digit == '.' && _current.isEmpty) ? '0.' : '$_current$digit';
    _current = next;
    widget.onChanged(next);
  }

  void _back() {
    if (_current.isEmpty) return;
    final next = _current.substring(0, _current.length - 1);
    _current = next;
    widget.onChanged(next);
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus?.context?.widget is EditableText) return false;

    final ch = event.character;
    if (ch != null && RegExp(r'^[0-9.]$').hasMatch(ch)) {
      _push(ch);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _back();
      return true;
    }
    if ((event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        widget.onEnter != null) {
      widget.onEnter!(_current);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const rows = <List<String>>[
      <String>['1', '2', '3'],
      <String>['4', '5', '6'],
      <String>['7', '8', '9'],
    ];

    final keyH = widget.keyHeight < AppDimensions.numPadKeyCompactH
        ? AppDimensions.numPadKeyCompactH
        : widget.keyHeight;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppDimensions.numPadMaxW),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows) ...[
            Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppDimensions.space2),
                  Expanded(
                    child: _NumKey(
                      label: row[i],
                      height: keyH,
                      onTap: () => _push(row[i]),
                      tokens: tokens,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: widget.rowGap),
          ],
          Row(
            children: [
              Expanded(
                child: widget.decimal
                    ? _NumKey(
                        label: '.',
                        height: keyH,
                        semanticLabel: 'จุดทศนิยม',
                        onTap: () => _push('.'),
                        tokens: tokens,
                      )
                    : SizedBox(height: keyH),
              ),
              const SizedBox(width: AppDimensions.space2),
              Expanded(
                child: _NumKey(
                  label: '0',
                  height: keyH,
                  onTap: () => _push('0'),
                  tokens: tokens,
                ),
              ),
              const SizedBox(width: AppDimensions.space2),
              Expanded(
                child: _BackspaceKey(
                  height: keyH,
                  onTap: _back,
                  tokens: tokens,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  const new({
    required this.label,
    required this.height,
    required this.onTap,
    required this.tokens,
    this.semanticLabel,
  });

  final String label;
  final double height;
  final VoidCallback onTap;
  final AppTokens tokens;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel ?? label,
    child: Material(
      color: tokens.surface.withValues(alpha: 0),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: SizedBox(
          height: height,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: tokens.ink,
                fontSize: AppDimensions.fs2xl,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BackspaceKey extends StatelessWidget {
  const new({required this.height, required this.onTap, required this.tokens});

  final double height;
  final VoidCallback onTap;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'ลบตัวเลขท้ายสุด',
    child: Material(
      color: tokens.surface.withValues(alpha: 0),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: SizedBox(
          height: height,
          child: Center(
            child: AppIcon(
              'backspace',
              size: AppDimensions.iconXl,
              color: tokens.muted,
            ),
          ),
        ),
      ),
    ),
  );
}
