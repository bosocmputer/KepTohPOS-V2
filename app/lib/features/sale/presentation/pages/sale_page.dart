import 'package:app/core/layout/shell_bars.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:app/features/sale/presentation/widgets/sale_main_content.dart';
import 'package:app/features/sale/presentation/widgets/sale_modals.dart';
import 'package:app/features/sale/presentation/widgets/sale_order_panel.dart';
import 'package:app/features/sale/presentation/widgets/sale_payment_panel.dart';
import 'package:app/features/sale/presentation/widgets/sale_receipt_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
export 'package:app/features/sale/presentation/widgets/sale_main_content.dart';
export 'package:app/features/sale/presentation/widgets/sale_modals.dart';
export 'package:app/features/sale/presentation/widgets/sale_order_panel.dart';
export 'package:app/features/sale/presentation/widgets/sale_payment_panel.dart';
export 'package:app/features/sale/presentation/widgets/sale_receipt_modal.dart';
export 'package:app/features/sale/presentation/widgets/sale_widgets.dart';

/// Cashier sale & order-pad screen (`function SaleView` in
/// `prototype/index.html` & `design/figma/cashier.png`).
class SalePage extends StatefulWidget {
  const new({
    required this.staff,
    required this.onBackToTables,
    required this.onSelectTable,
    super.key,
    this.onRequestOpenShift,
  });

  final StaffMember staff;
  final VoidCallback onBackToTables;
  final ValueChanged<String> onSelectTable;
  final VoidCallback? onRequestOpenShift;

  @override
  State<SalePage> createState() => _SalePageState();
}

class _SalePageState extends State<SalePage> {
  final ScrollController _mobileScrollCtrl = ScrollController();
  bool _showNoteModal = false;
  String? _removeSelection;
  bool _showCloseConfirm = false;

  @override
  void dispose() {
    _mobileScrollCtrl.dispose();
    super.dispose();
  }

  Widget _buildPanel(SaleState state, {required bool fullHeight}) =>
      state.step == 'pay'
      ? SalePaymentPanel(
          state: state,
          staff: widget.staff,
          fullHeight: fullHeight,
        )
      : SaleOrderPanel(
          state: state,
          staff: widget.staff,
          fullHeight: fullHeight,
          onSelectTable: widget.onSelectTable,
          onOpenNoteModal: () => setState(() => _showNoteModal = true),
          onOpenRemoveModal: (sel) => setState(() => _removeSelection = sel),
        );

  Widget _buildMain(SaleState state, DiningTable tb) => SaleMainContent(
    state: state,
    table: tb,
    onBackToTables: widget.onBackToTables,
    onSelectTable: widget.onSelectTable,
    onRequestOpenShift: widget.onRequestOpenShift,
    onRequestCloseTable: () => setState(() => _showCloseConfirm = true),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final headerScope = ShellDesktopHeaderScope.maybeOf(context);

    return BlocConsumer<SaleBloc, SaleState>(
      listenWhen: (prev, curr) =>
          curr.toastMessage.isNotEmpty &&
          curr.toastMessage != prev.toastMessage,
      listener: (context, state) {
        showAppToast(context, state.toastMessage);
        context.read<SaleBloc>().add(const SaleToastCleared());
      },
      builder: (context, state) {
        final tb = state.table;
        if (tb == null) {
          return Padding(
            padding: const EdgeInsets.all(AppDimensions.space6),
            child: Empty(
              title: 'ไม่พบโต๊ะนี้',
              text: 'โต๊ะอาจถูกลบไปแล้ว',
              action: Btn(
                label: 'กลับหน้าโต๊ะ',
                kind: BtnKind.primary,
                onPressed: widget.onBackToTables,
              ),
            ),
          );
        }

        final desktopHeader = headerScope?.headerBuilder(
          titleWidget: buildSaleTopbarTitle(
            context,
            state,
            tb,
            widget.onBackToTables,
          ),
          extraActions: <Widget>[
            if (state.openTable != null)
              Btn(
                key: const ValueKey('topbar-close-table-btn'),
                kind: BtnKind.danger,
                label: 'เก็บโต๊ะ',
                onPressed: () => setState(() => _showCloseConfirm = true),
              ),
          ],
        );

        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final screenW = constraints.maxWidth;
                if (screenW > AppDimensions.mobileBp) {
                  final pagePad = AppDimensions.pagePadding(screenW);
                  final panelW = AppDimensions.rightPanelWidth(screenW);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ?desktopHeader,
                            Expanded(
                              child: SafeArea(
                                top: false,
                                right: false,
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.all(pagePad),
                                  child: _buildMain(state, tb),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: panelW,
                        height: double.infinity,
                        child: _buildPanel(state, fullHeight: true),
                      ),
                    ],
                  );
                }

                final payTotal = state.payOrder.total;
                final showBar = state.hasCart || payTotal > 0;
                final barStyle = Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: t.onPrimary, fontWeight: FontWeight.w700);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _mobileScrollCtrl,
                        padding: const EdgeInsets.all(AppDimensions.space4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildMain(state, tb),
                            const SizedBox(height: AppDimensions.space4),
                            _buildPanel(state, fullHeight: false),
                          ],
                        ),
                      ),
                    ),
                    if (showBar)
                      Material(
                        color: t.primary,
                        child: InkWell(
                          key: const ValueKey('mobile-view-order-bar'),
                          onTap: () {
                            if (_mobileScrollCtrl.hasClients) {
                              _mobileScrollCtrl.animateTo(
                                _mobileScrollCtrl.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.space4,
                              vertical: AppDimensions.space3,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ดูออเดอร์โต๊ะ ${tb.name}',
                                  style: barStyle,
                                ),
                                Text(
                                  '${baht(payTotal, payTotal % 1 != 0 ? 2 : 0)}'
                                  ' ›',
                                  style: barStyle,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_showNoteModal)
              NoteModal(
                initialValue: state.effectiveNotes,
                onClose: () => setState(() => _showNoteModal = false),
                onSave: (notes) {
                  context.read<SaleBloc>().add(SaleNotesSaved(notes));
                  setState(() => _showNoteModal = false);
                },
              ),
            if (_removeSelection != null)
              RemoveItemModal(
                lines: state.sentRows,
                initialSelection: _removeSelection!,
                onClose: () => setState(() => _removeSelection = null),
                onSave: (kind, key, qty, reason) {
                  context.read<SaleBloc>().add(
                    SaleSentItemAdjusted(
                      kind: kind,
                      key: key,
                      qty: qty,
                      reason: reason,
                      staff: widget.staff,
                    ),
                  );
                  setState(() => _removeSelection = null);
                },
              ),
            if (_showCloseConfirm)
              CloseTableConfirmModal(
                tableName: tb.name,
                due: state.due,
                onClose: () => setState(() => _showCloseConfirm = false),
                onConfirm: () {
                  context.read<SaleBloc>().add(const SaleTableClosed());
                  setState(() => _showCloseConfirm = false);
                  widget.onBackToTables();
                },
              ),
            if (state.settledBill != null)
              ReceiptModal(
                shop: state.posState.shop,
                bill: state.settledBill!,
                doneLabel:
                    state.effectiveTiming == 'after' && state.openTable != null
                    ? 'เสร็จสิ้น · เก็บโต๊ะ'
                    : null,
                onPrint: () =>
                    showAppToast(context, 'ส่งพิมพ์ใบเสร็จแล้ว (จำลอง)'),
                onDone: () {
                  final bloc = context.read<SaleBloc>();
                  if (state.effectiveTiming == 'after' &&
                      state.openTable != null &&
                      state.due == 0) {
                    bloc.add(const SaleTableClosed());
                  }
                  bloc.add(const SaleReceiptDismissed());
                  widget.onBackToTables();
                },
              ),
          ],
        );
      },
    );
  }
}
