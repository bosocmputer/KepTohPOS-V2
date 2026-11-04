import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:flutter/material.dart';

/// Warning banner shown on `ShiftPage` when eat-before-paying tables still owe.
class OwingTablesBanner extends StatelessWidget {
  const new({required this.state, required this.onGoTables, super.key});

  final ShiftState state;
  final VoidCallback onGoTables;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final names = state.owingTables.map((x) => x.name).join(', ');
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space4),
      decoration: BoxDecoration(
        color: tokens.primarySoft,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'มีโต๊ะค้างชำระ (กินก่อนจ่าย) $names รวม '
              '${baht(state.owedTotal)} · ปิดกะได้ '
              'แต่ยอดนี้จะยังไม่อยู่ในกะนี้',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.primaryInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space3),
          Btn(
            label: 'ไปหน้าโต๊ะ',
            kind: BtnKind.primary,
            size: BtnSize.sm,
            onPressed: onGoTables,
          ),
        ],
      ),
    );
  }
}

/// 14-shift history table (`DataTable` in `ShiftView` of `index.html`).
class ShiftHistoryTable extends StatelessWidget {
  const new({required this.state, super.key});

  final ShiftState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return PosDataTable<ShiftRecord>(
      label: 'ประวัติกะ',
      rows: state.history,
      empty: const Empty(title: 'ยังไม่มีประวัติกะ'),
      columns: [
        DataTableCol(
          key: 'd',
          label: 'วันที่',
          cellBuilder: (_, h) =>
              Text(thDate(dkey(DateTime.parse(h.openedAt).toLocal()))),
        ),
        DataTableCol(
          key: 'who',
          label: 'ผู้เปิดกะ',
          cellBuilder: (_, h) => Text(state.staffNameOf(h.staffId)),
        ),
        DataTableCol(
          key: 'bills',
          label: 'บิล',
          align: ColAlign.right,
          cellBuilder: (_, h) => Text('${state.statsOf(h).bills}'),
        ),
        DataTableCol(
          key: 'cash',
          label: 'ขายเงินสด',
          align: ColAlign.right,
          cellBuilder: (_, h) => Text(fmt(state.statsOf(h).cash)),
        ),
        DataTableCol(
          key: 'qr',
          label: 'QR/โอน',
          align: ColAlign.right,
          cellBuilder: (_, h) {
            final st = state.statsOf(h);
            return Text(fmt(st.qr + st.transfer));
          },
        ),
        DataTableCol(
          key: 'exp',
          label: 'ควรมี',
          align: ColAlign.right,
          cellBuilder: (_, h) => Text(fmt(state.statsOf(h).expected)),
        ),
        DataTableCol(
          key: 'cnt',
          label: 'นับได้',
          align: ColAlign.right,
          cellBuilder: (_, h) => Text(fmt(h.counted)),
        ),
        DataTableCol(
          key: 'diff',
          label: 'ส่วนต่าง',
          align: ColAlign.right,
          cellBuilder: (_, h) {
            final d = (h.counted ?? 0) - state.statsOf(h).expected;
            final text = d == 0 ? 'ตรง' : '${d > 0 ? "+" : ""}${fmt(d)}';
            return Text(
              text,
              style: TextStyle(
                color: d == 0 ? tokens.success : tokens.danger,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
      ],
    );
  }
}
