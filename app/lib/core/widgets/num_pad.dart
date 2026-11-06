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
    this.maxDecimalPlaces,
    this.keyboard = false,
    this.keyHeight = AppDimensions.numPadKeyH,
    this.rowGap = AppDimensions.space2,
    this.colGap = AppDimensions.space2,
    this.maxWidth = AppDimensions.numPadMaxW,
    this.filledKeys = false,
    this.showClear = false,
    this.onEnter,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int maxLen;
  final bool decimal;
  final int? maxDecimalPlaces;
  final bool keyboard;
  final double keyHeight;
  final double rowGap;
  final double colGap;
  final double maxWidth;
  final bool filledKeys;
  final bool showClear;
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
    if (digit != '.' &&
        widget.maxDecimalPlaces != null &&
        _current.contains('.')) {
      final dotIdx = _current.indexOf('.');
      if (_current.length - dotIdx - 1 >= widget.maxDecimalPlaces!) return;
    }
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
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows) ...[
            Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) SizedBox(width: widget.colGap),
                  Expanded(
                    child: _NumKey(
                      label: row[i],
                      height: keyH,
                      filled: widget.filledKeys,
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
                        filled: widget.filledKeys,
                        semanticLabel: 'จุดทศนิยม',
                        onTap: () => _push('.'),
                        tokens: tokens,
                      )
                    : widget.showClear
                    ? _NumKey(
                        label: 'C',
                        height: keyH,
                        filled: widget.filledKeys,
                        semanticLabel: 'ล้างตัวเลข',
                        onTap: () {
                          _current = '';
                          widget.onChanged('');
                        },
                        tokens: tokens,
                      )
                    : SizedBox(height: keyH),
              ),
              SizedBox(width: widget.colGap),
              Expanded(
                child: _NumKey(
                  label: '0',
                  height: keyH,
                  filled: widget.filledKeys,
                  onTap: () => _push('0'),
                  tokens: tokens,
                ),
              ),
              SizedBox(width: widget.colGap),
              Expanded(
                child: _BackspaceKey(
                  height: keyH,
                  filled: widget.filledKeys,
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
    required this.filled,
    required this.onTap,
    required this.tokens,
    this.semanticLabel,
  });

  final String label;
  final double height;
  final bool filled;
  final VoidCallback onTap;
  final AppTokens tokens;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Material(
    color: filled ? tokens.surface2 : tokens.surface.withValues(alpha: 0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      side: filled ? BorderSide(color: tokens.line) : BorderSide.none,
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: SizedBox(
        height: height,
        child: Center(
          child: Text(
            label,
            semanticsLabel: semanticLabel,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: tokens.ink,
              fontSize: filled ? AppDimensions.fs3xl : AppDimensions.fs2xl,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _BackspaceKey extends StatelessWidget {
  const new({
    required this.height,
    required this.filled,
    required this.onTap,
    required this.tokens,
  });
  final double height;
  final bool filled;
  final VoidCallback onTap;
  final AppTokens tokens;
  @override
  Widget build(BuildContext context) => Material(
    color: filled ? tokens.surface2 : tokens.surface.withValues(alpha: 0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      side: filled ? BorderSide(color: tokens.line) : BorderSide.none,
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Semantics(
        label: 'ลบตัวเลขท้ายสุด',
        child: SizedBox(
          height: height,
          child: Center(
            child: AppIcon(
              'backspace',
              size: AppDimensions.iconXl,
              color: filled ? tokens.ink : tokens.muted,
            ),
          ),
        ),
      ),
    ),
  );
}
