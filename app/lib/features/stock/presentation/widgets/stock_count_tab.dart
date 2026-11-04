import 'package:app/core/theme/tokens.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/bloc/stock_count_bloc.dart';
import 'package:app/features/stock/presentation/widgets/stock_count_numpad_panel.dart';
import 'package:app/features/stock/presentation/widgets/stock_count_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/stock/presentation/widgets/stock_count_table.dart';

/// Fast daily/weekly stock count tab (`StockCount` in `index.html:1352-1417`).
class StockCountTab extends StatefulWidget {
  const new({required this.staff, super.key});

  final StaffMember staff;

  @override
  State<StockCountTab> createState() => _StockCountTabState();
}

class _StockCountTabState extends State<StockCountTab> {
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String ingId) => _rowKeys.putIfAbsent(ingId, GlobalKey.new);

  void _scrollToActive(String? ingId) {
    if (ingId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _rowKeys[ingId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 120),
          alignment: 0.35,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final state = context.watch<StockCountBloc>().state;
    final bloc = context.read<StockCountBloc>();
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW <= AppDimensions.mobileBp;
    final curId = state.currentIngredientId;

    final listColumn = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? AppDimensions.space4 : AppDimensions.space6,
        AppDimensions.space4,
        isMobile ? AppDimensions.space4 : AppDimensions.space5,
        AppDimensions.space6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space4,
              vertical: AppDimensions.space2_5,
            ),
            decoration: BoxDecoration(
              color: state.isClosed ? t.primarySoft : t.surface,
              borderRadius: BorderRadius.circular(AppDimensions.r),
              border: Border.all(color: state.isClosed ? t.primary : t.line),
            ),
            child: Text(
              state.isClosed
                  ? 'ปิดยอดแล้ว · แก้ตัวเลขแล้วกดบันทึกได้'
                  : 'แตะรายการแล้วป้อนจำนวนที่เหลือ · Enter = รายการถัดไป',
              style: tt.bodyMedium?.copyWith(
                color: state.isClosed ? t.primaryInk : t.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (state.skippedWeeklyCount > 0) ...[
            const SizedBox(height: AppDimensions.space2),
            Text(
              'ของนับรายสัปดาห์ '
              '(นับวัน${kDowNames[state.posState.shop.weeklyCountDow % 7]}) '
              '${state.skippedWeeklyCount} รายการ '
              'ระบบใช้ค่าประมาณจากอัตราใช้ต่อหัว',
              style: tt.bodySmall?.copyWith(color: t.muted),
            ),
          ],
          const SizedBox(height: AppDimensions.space4),
          for (final group in state.locationGroups) ...[
            Row(
              children: [
                Text(
                  kLocations[group.key] ?? group.key,
                  style: tt.titleMedium?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppDimensions.space2),
                Text(
                  '${group.value.length} รายการ',
                  style: tt.bodySmall?.copyWith(color: t.muted),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space2),
            LocationCountTable(
              items: group.value,
              state: state,
              activeId: curId,
              keyOf: _keyFor,
              onSelectRow: (id) => bloc.add(StockCountItemSelected(id)),
            ),
            const SizedBox(height: AppDimensions.space4),
          ],
        ],
      ),
    );

    return BlocListener<StockCountBloc, StockCountState>(
      listenWhen: (prev, curr) =>
          prev.currentIngredientId != curr.currentIngredientId,
      listener: (context, s) => _scrollToActive(s.currentIngredientId),
      child: isMobile
          ? Column(
              children: [
                Expanded(child: listColumn),
                StockCountNumPadPanel(
                  state: state,
                  staff: widget.staff,
                  isMobile: true,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: listColumn),
                SizedBox(
                  width: AppDimensions.rightPanelWidth(screenW),
                  child: StockCountNumPadPanel(
                    state: state,
                    staff: widget.staff,
                    isMobile: false,
                  ),
                ),
              ],
            ),
    );
  }
}
