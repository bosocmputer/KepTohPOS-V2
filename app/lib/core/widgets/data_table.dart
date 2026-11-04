import 'dart:math' as math;

import 'package:app/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Column alignment in [PosDataTable] (`align: 'l' | 'c' | 'r'`).
enum ColAlign { left, center, right }

/// Column definition for [PosDataTable] (`columns` in `prototype/index.html`).
class DataTableCol<T> {
  const new({
    required this.key,
    required this.label,
    required this.cellBuilder,
    this.align = ColAlign.left,
    this.flex = 1,
  });

  final String key;
  final String label;
  final ColAlign align;
  final int flex;
  final Widget Function(BuildContext context, T row) cellBuilder;
}

/// Shared data table component (`DataTable` in `prototype/index.html` & Figma
/// `design/figma/history.png`). Stretches to full width of its parent container.
class PosDataTable<T> extends StatelessWidget {
  const new({
    required this.columns,
    required this.rows,
    super.key,
    this.onRowTap,
    this.activeRowPredicate,
    this.footerCells,
    this.showHeader = true,
    this.empty,
    this.label,
  });

  final List<DataTableCol<T>> columns;
  final List<T> rows;
  final ValueChanged<T>? onRowTap;
  final bool Function(T row)? activeRowPredicate;
  final List<Widget>? footerCells;
  final bool showHeader;
  final Widget? empty;
  final String? label;

  Alignment _alignment(ColAlign align) => switch (align) {
    ColAlign.right => Alignment.centerRight,
    ColAlign.center => Alignment.center,
    ColAlign.left => Alignment.centerLeft,
  };

  TextAlign _textAlign(ColAlign align) => switch (align) {
    ColAlign.right => TextAlign.right,
    ColAlign.center => TextAlign.center,
    ColAlign.left => TextAlign.left,
  };

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && empty != null) return empty!;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: label,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AppDimensions.r),
          border: Border.all(color: tokens.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = constraints.hasBoundedWidth
                ? math.max<double>(constraints.maxWidth, 520)
                : 520.0;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHeader)
                      Container(
                        color: tokens.surface2,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.space2_5,
                          horizontal: AppDimensions.space3,
                        ),
                        child: Row(
                          children: [
                            for (final col in columns)
                              Expanded(
                                flex: col.flex,
                                child: Align(
                                  alignment: _alignment(col.align),
                                  child: Text(
                                    col.label,
                                    textAlign: _textAlign(col.align),
                                    style: textTheme.labelSmall?.copyWith(
                                      color: tokens.muted,
                                      fontSize: AppDimensions.fsXs,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    for (var i = 0; i < rows.length; i++)
                      _buildRow(context, rows[i], i == rows.length - 1, tokens),
                    if (footerCells != null && footerCells!.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: tokens.surface2,
                          border: Border(
                            top: BorderSide(
                              color: tokens.line,
                              width: AppDimensions.borderThick,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.space2_5,
                          horizontal: AppDimensions.space3,
                        ),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            color: tokens.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: AppDimensions.fsSm,
                          ),
                          child: Row(
                            children: [
                              for (var i = 0; i < footerCells!.length; i++)
                                Expanded(
                                  child: Align(
                                    alignment: i < columns.length
                                        ? _alignment(columns[i].align)
                                        : Alignment.centerLeft,
                                    child: footerCells![i],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, T row, bool isLast, AppTokens tokens) {
    final isActive = activeRowPredicate?.call(row) ?? false;
    final rowContent = Container(
      decoration: BoxDecoration(
        color: isActive
            ? tokens.primarySoft
            : tokens.surface.withValues(alpha: 0),
        border: Border(
          left: isActive
              ? BorderSide(
                  color: tokens.primary,
                  width: AppDimensions.borderAccent,
                )
              : BorderSide.none,
          bottom: isLast ? BorderSide.none : BorderSide(color: tokens.line),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.space2_5,
        horizontal: AppDimensions.space3,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: tokens.ink, fontSize: AppDimensions.fsSm),
        child: Row(
          children: [
            for (final col in columns)
              Expanded(
                flex: col.flex,
                child: Align(
                  alignment: _alignment(col.align),
                  child: col.cellBuilder(context, row),
                ),
              ),
          ],
        ),
      ),
    );

    if (onRowTap == null) return rowContent;
    return Material(
      color: tokens.surface.withValues(alpha: 0),
      child: InkWell(onTap: () => onRowTap!(row), child: rowContent),
    );
  }
}
