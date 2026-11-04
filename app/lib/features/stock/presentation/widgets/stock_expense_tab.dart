import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/stock/presentation/cubit/stock_cubit.dart';
import 'package:app/features/stock/presentation/widgets/expense_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Daily operating expenses tab (`StockExpense` in `index.html:1463-1480`).
class StockExpenseTab extends StatefulWidget {
  const new({required this.staff, super.key});

  final StaffMember staff;

  @override
  State<StockExpenseTab> createState() => _StockExpenseTabState();
}

class _StockExpenseTabState extends State<StockExpenseTab> {
  bool _modalOpen = false;
  String? _editId;
  List<ExpenseRecord> _modalSeed = const <ExpenseRecord>[];
  ExpenseRecord? _deletingExpense;

  void _openNew() {
    setState(() {
      _modalOpen = true;
      _editId = null;
      _modalSeed = const <ExpenseRecord>[];
    });
  }

  void _openCopyPrevious() {
    final prevList = context.read<StockCubit>().state.prevDateExpenses;
    if (prevList.isEmpty) return;
    setState(() {
      _modalOpen = true;
      _editId = null;
      _modalSeed = prevList;
    });
  }

  void _openEdit(ExpenseRecord e) {
    if (widget.staff.role == 'cashier') return;
    setState(() {
      _modalOpen = true;
      _editId = e.id;
      _modalSeed = <ExpenseRecord>[e];
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final state = context.watch<StockCubit>().state;
    final cubit = context.read<StockCubit>();
    final canManage = widget.staff.role != 'cashier';
    final rows = state.dayExpenses;
    final prevDate = state.prevExpenseDate;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'ค่าใช้จ่ายวันที่ ${thDateShort(state.selectedDate)}',
                desc: 'ไม่เข้าสต็อก · ใช้หักกำไรสุทธิ',
                actions: [
                  Btn(
                    key: const ValueKey('expense-copy-prev-btn'),
                    icon: 'copy',
                    label: 'เหมือนครั้งก่อน',
                    disabled: prevDate == null,
                    onPressed: _openCopyPrevious,
                  ),
                  Btn(
                    key: const ValueKey('expense-add-btn'),
                    kind: BtnKind.primary,
                    icon: 'plus',
                    label: 'เพิ่มค่าใช้จ่าย',
                    onPressed: _openNew,
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space4),
              PosDataTable<ExpenseRecord>(
                rows: rows,
                empty: Empty(
                  title: 'ยังไม่มีค่าใช้จ่ายวันนี้',
                  text: prevDate != null
                      ? 'กด เหมือนครั้งก่อน เพื่อคัดลอกจากวันที่ '
                            '${thDateShort(prevDate)}'
                      : '',
                ),
                columns: [
                  DataTableCol<ExpenseRecord>(
                    key: 'type',
                    label: 'รายการ',
                    flex: 2,
                    cellBuilder: (context, e) => Text(
                      state.expenseTypeNameOf(e.typeId),
                      style: tt.bodyMedium?.copyWith(
                        color: t.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DataTableCol<ExpenseRecord>(
                    key: 'note',
                    label: 'หมายเหตุ',
                    flex: 2,
                    cellBuilder: (context, e) => Text(
                      e.note.isNotEmpty ? e.note : '–',
                      style: tt.bodyMedium?.copyWith(color: t.muted),
                    ),
                  ),
                  DataTableCol<ExpenseRecord>(
                    key: 'amount',
                    label: 'ยอด',
                    align: ColAlign.right,
                    cellBuilder: (context, e) => Text(
                      baht(e.amount),
                      textAlign: TextAlign.right,
                      style: tt.bodyMedium?.copyWith(
                        color: t.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (canManage)
                    DataTableCol<ExpenseRecord>(
                      key: 'act',
                      label: 'จัดการ',
                      align: ColAlign.right,
                      cellBuilder: (context, e) => Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Btn(
                            key: ValueKey('expense-edit-${e.id}'),
                            size: BtnSize.sm,
                            icon: 'edit',
                            semanticLabel:
                                'แก้ไข ${state.expenseTypeNameOf(e.typeId)}',
                            onPressed: () => _openEdit(e),
                          ),
                          const SizedBox(width: AppDimensions.space1_5),
                          Btn(
                            key: ValueKey('expense-delete-${e.id}'),
                            size: BtnSize.sm,
                            kind: BtnKind.danger,
                            icon: 'trash',
                            semanticLabel:
                                'ลบ ${state.expenseTypeNameOf(e.typeId)}',
                            onPressed: () =>
                                setState(() => _deletingExpense = e),
                          ),
                        ],
                      ),
                    ),
                ],
                footerCells: [
                  const Text('รวม'),
                  const SizedBox.shrink(),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      baht(state.dayExpensesTotal),
                      key: const ValueKey('expense-day-total'),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  if (canManage) const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),
        if (_modalOpen)
          ExpenseModal(
            date: state.selectedDate,
            expenseTypes: state.posState.expenseTypes,
            initialLines: _modalSeed,
            editId: _editId,
            onClose: () => setState(() => _modalOpen = false),
            onSave: (lines) {
              final ok = cubit.submitExpenses(
                date: state.selectedDate,
                lines: lines,
                staff: widget.staff,
                editId: _editId,
              );
              if (ok) {
                setState(() => _modalOpen = false);
              }
            },
          ),
        if (_deletingExpense != null)
          RootOverlayBox(
            child: Material(
              color: t.scrim,
              child: SafeArea(
                child: Confirm(
                  title: 'ลบค่าใช้จ่ายนี้?',
                  text:
                      '${state.expenseTypeNameOf(_deletingExpense!.typeId)} · '
                      '${baht(_deletingExpense!.amount)}',
                  yesLabel: 'ลบ',
                  danger: true,
                  onNo: () => setState(() => _deletingExpense = null),
                  onYes: () {
                    final target = _deletingExpense!;
                    setState(() => _deletingExpense = null);
                    cubit.removeExpense(
                      expenseId: target.id,
                      staff: widget.staff,
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
