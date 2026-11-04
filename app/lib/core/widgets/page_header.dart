import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';

/// Page title bar (`PageHeader` in `prototype/index.html` & Figma).
class PageHeader extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.desc,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? desc;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: textTheme.displaySmall?.copyWith(color: tokens.ink)),
        if (desc != null && desc!.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.space1),
          Text(
            desc!,
            style: textTheme.bodySmall?.copyWith(color: tokens.muted),
          ),
        ],
      ],
    );
    final actionsWrap = Wrap(
      spacing: AppDimensions.space2_5,
      runSpacing: AppDimensions.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (actions.isEmpty) return titleBlock;
        if (constraints.maxWidth <= AppDimensions.modalW) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleBlock,
              const SizedBox(height: AppDimensions.space3),
              actionsWrap,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: AppDimensions.space3),
            Flexible(child: actionsWrap),
          ],
        );
      },
    );
  }
}

/// Filter/search toolbar (`Toolbar` in `prototype/index.html`).
class Toolbar extends StatelessWidget {
  const new({required this.children, super.key, this.end = const <Widget>[]});

  final List<Widget> children;
  final List<Widget> end;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppDimensions.space3,
    runSpacing: AppDimensions.space3,
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.end,
    children: [
      Wrap(
        spacing: AppDimensions.space3,
        runSpacing: AppDimensions.space3,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: children,
      ),
      if (end.isNotEmpty)
        Wrap(
          spacing: AppDimensions.space3,
          runSpacing: AppDimensions.space3,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: end,
        ),
    ],
  );
}

/// Search input box (`SearchBox` in `prototype/index.html` & Figma Header).
class SearchBox extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    super.key,
    this.placeholder = 'ค้นหา',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.tap,
        minWidth: 200,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space3),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(
          color: tokens.line,
          width: AppDimensions.borderThick,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon('search', size: AppDimensions.iconSm, color: tokens.muted),
          const SizedBox(width: AppDimensions.space2),
          Flexible(
            child: TextField(
              controller: TextEditingController(text: value)
                ..selection = TextSelection.collapsed(offset: value.length),
              onChanged: onChanged,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tokens.ink),
              decoration: InputDecoration(
                isDense: true,
                hintText: placeholder,
                hintStyle: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: tokens.muted),
                border: InputBorder.none,
              ),
            ),
          ),
          if (value.isNotEmpty)
            IconButton(
              icon: AppIcon(
                'x',
                size: AppDimensions.iconXs,
                color: tokens.muted,
              ),
              tooltip: 'ล้างคำค้น',
              onPressed: () => onChanged(''),
            ),
        ],
      ),
    );
  }
}

/// Staff avatar circle (`Avatar` in `prototype/index.html`).
class Avatar extends StatelessWidget {
  const new({
    required this.name,
    super.key,
    this.size = AppDimensions.avatarMd,
  });

  final String name;
  final double size;

  String get _initial {
    final cleaned = name.replaceFirst(RegExp('^(คุณ|น้อง|พี่)'), '').trim();
    final match = RegExp('[ก-ฮA-Za-z0-9]').firstMatch(cleaned);
    return match != null ? match.group(0)! : '?';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initial,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: tokens.primaryInk,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
