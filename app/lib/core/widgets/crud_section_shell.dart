import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/btn.dart';
import 'package:app/core/widgets/data_table.dart';
import 'package:app/core/widgets/empty.dart';
import 'package:app/core/widgets/page_header.dart';
import 'package:flutter/material.dart';

/// Reusable CRUD table section (`CrudSection` in `prototype/index.html:1019`)
/// combining a [PageHeader], optional summary strip, `+ เพิ่ม` action button,
/// and a [PosDataTable] with standardized trailing `แก้ไข` / `ลบ` row actions.
class CrudSectionShell<T> extends StatelessWidget {
  const new({
    required this.title,
    required this.desc,
    required this.rows,
    required this.columns,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.itemNameOf,
    super.key,
    this.addButtonKey,
    this.addLabel = 'เพิ่มรายการ',
    this.summaryBanner,
    this.headerPills = const <Widget>[],
    this.canWrite = true,
    this.lockedReason,
  });

  final String title;
  final String desc;
  final List<T> rows;
  final List<DataTableCol<T>> columns;
  final VoidCallback onAdd;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onDelete;
  final String Function(T item) itemNameOf;
  final Key? addButtonKey;
  final String addLabel;
  final Widget? summaryBanner;
  final List<Widget> headerPills;
  final bool canWrite;
  final String? lockedReason;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;

    final allColumns = <DataTableCol<T>>[
      for (final col in columns)
        DataTableCol<T>(
          key: col.key,
          label: col.label,
          flex: col.flex,
          align: col.align,
          cellBuilder: (ctx, item) => Padding(
            padding: const EdgeInsets.only(right: AppDimensions.space2_5),
            child: col.cellBuilder(ctx, item),
          ),
        ),
      if (canWrite)
        DataTableCol<T>(
          key: '_actions',
          label: 'จัดการ',
          flex: 2,
          align: ColAlign.right,
          cellBuilder: (context, item) {
            final name = itemNameOf(item);
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Btn(
                  size: BtnSize.sm,
                  icon: 'edit',
                  semanticLabel: 'แก้ไข $name',
                  onPressed: () => onEdit(item),
                ),
                const SizedBox(width: AppDimensions.space1_5),
                Btn(
                  size: BtnSize.sm,
                  kind: BtnKind.danger,
                  icon: 'trash',
                  semanticLabel: 'ลบ $name',
                  onPressed: () => onDelete(item),
                ),
              ],
            );
          },
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: title,
          desc: desc,
          actions: [
            ...headerPills,
            if (canWrite)
              Btn(
                key: addButtonKey,
                kind: BtnKind.primary,
                icon: 'plus',
                label: addLabel,
                onPressed: onAdd,
              ),
          ],
        ),
        if (!canWrite && lockedReason != null) ...[
          const SizedBox(height: AppDimensions.space2_5),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space3_5,
              vertical: AppDimensions.space2_5,
            ),
            decoration: BoxDecoration(
              color: t.primarySoft,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: t.primary.withValues(alpha: 0.35)),
            ),
            child: Text(
              lockedReason!,
              style: tt.bodySmall?.copyWith(
                color: t.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (summaryBanner != null) ...[
          const SizedBox(height: AppDimensions.space3),
          summaryBanner!,
        ],
        const SizedBox(height: AppDimensions.space3),
        PosDataTable<T>(
          label: title,
          rows: rows,
          onRowTap: canWrite ? onEdit : null,
          empty: Empty(
            title: 'ยังไม่มีรายการในหมวด$title',
            text: canWrite
                ? 'กดปุ่ม "$addLabel" ด้านบนเพื่อสร้างรายการแรก'
                : '',
          ),
          columns: allColumns,
        ),
      ],
    );
  }
}
