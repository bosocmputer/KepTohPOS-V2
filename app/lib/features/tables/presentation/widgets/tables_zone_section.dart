import 'package:app/core/theme/tokens.dart';
import 'package:app/features/tables/presentation/cubit/tables_cubit.dart';
import 'package:app/features/tables/presentation/widgets/table_card.dart';
import 'package:flutter/material.dart';

/// Tables of one zone on the tables page.
class ZoneTablesSection extends StatelessWidget {
  const new({
    required this.zone,
    required this.state,
    required this.onSelectTable,
    required this.onViewSlip,
    super.key,
  });

  final String zone;
  final TablesState state;
  final ValueChanged<String> onSelectTable;
  final ValueChanged<String> onViewSlip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final tables = state.tablesInZone(zone);
    if (tables.isEmpty) return const SizedBox.shrink();
    final free = state.freeInZone(zone);
    final total = state.totalInZone(zone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(zone, style: tt.headlineMedium?.copyWith(color: t.ink)),
            const SizedBox(width: AppDimensions.space2_5),
            Text(
              'ว่าง $free จาก $total',
              style: tt.bodySmall?.copyWith(color: t.muted),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space3),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cols = w >= 1100 ? 5 : (w >= 840 ? 4 : (w >= 560 ? 3 : 2));
            const spacing = AppDimensions.space3;
            final itemW = (w - (cols - 1) * spacing) / cols;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final tb in tables)
                  SizedBox(
                    width: itemW,
                    child: TableCard(
                      posState: state.posState,
                      table: tb,
                      openTable: state.posState.openTables[tb.id],
                      now: state.now,
                      onTap: () => onSelectTable(tb.id),
                      onViewSlip: state.posState.openTables[tb.id] != null
                          ? () => onViewSlip(tb.id)
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
