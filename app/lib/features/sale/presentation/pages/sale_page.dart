import 'package:app/core/layout/shell_bars.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
import 'package:app/features/sale/presentation/widgets/sale_main_content.dart';
import 'package:app/features/sale/presentation/widgets/sale_modals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/sale/presentation/bloc/sale_bloc.dart';
export 'package:app/features/sale/presentation/widgets/sale_main_content.dart';
export 'package:app/features/sale/presentation/widgets/sale_modals.dart';

/// Cashier sale & order-pad screen (`function SaleView` in `prototype/index.html`).
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
  bool _showPosSlipModal = false;

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
          onOpenPosSlipModal: state.openTable != null
              ? () => setState(() => _showPosSlipModal = true)
              : null,
        );

  Widget _buildMain(SaleState state, DiningTable tb) => SaleMainContent(
    state: state,
    table: tb,
    onBackToTables: widget.onBackToTables,
    onSelectTable: widget.onSelectTable,
    onRequestOpenShift: widget.onRequestOpenShift,
    onRequestCloseTable: () => setState(() => _showCloseConfirm = true),
    onRequestViewSlip: () => setState(() => _showPosSlipModal = true),
  );

  @override
  Widget build(BuildContext context) {
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
          return Empty(
            title: 'ไม่พบโต๊ะนี้',
            text: 'โต๊ะอาจถูกลบไปแล้ว',
            action: Btn(
              label: 'กลับหน้าโต๊ะ',
              kind: BtnKind.primary,
              onPressed: widget.onBackToTables,
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
            if (state.openTable != null) ...[
              Btn(
                key: const ValueKey('topbar-pos-slip-btn'),
                icon: 'receipt',
                label: 'ดูสลิป POS',
                onPressed: () => setState(() => _showPosSlipModal = true),
              ),
              Btn(
                key: const ValueKey('topbar-close-table-btn'),
                kind: BtnKind.danger,
                label: 'เก็บโต๊ะ',
                onPressed: () => setState(() => _showCloseConfirm = true),
              ),
            ],
          ],
        );
        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final screenW = constraints.maxWidth;
                if (screenW > AppDimensions.mobileBp) {
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
                                  padding: EdgeInsets.all(
                                    AppDimensions.pagePadding(screenW),
                                  ),
                                  child: _buildMain(state, tb),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: AppDimensions.rightPanelWidth(screenW),
                        height: double.infinity,
                        child: _buildPanel(state, fullHeight: true),
                      ),
                    ],
                  );
                }
                final payTotal = state.payOrder.total;
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
                    if (state.hasCart || payTotal > 0)
                      buildSaleMobileBottomBar(
                        context,
                        state,
                        tb,
                        _mobileScrollCtrl,
                      ),
                  ],
                );
              },
            ),
            ..._buildOverlays(context, state, tb),
          ],
        );
      },
    );
  }

  List<Widget> _buildOverlays(
    BuildContext context,
    SaleState state,
    DiningTable tb,
  ) {
    final bloc = context.read<SaleBloc>();
    final isSettled = state.settledBill != null;
    final modalBill =
        state.settledBill ?? (_showPosSlipModal ? state.tablePosSlip : null);
    return [
      if (_showNoteModal)
        NoteModal(
          initialValue: state.effectiveNotes,
          onClose: () => setState(() => _showNoteModal = false),
          onSave: (notes) {
            bloc.add(SaleNotesSaved(notes));
            setState(() => _showNoteModal = false);
          },
        ),
      if (_removeSelection != null)
        RemoveItemModal(
          lines: state.sentRows,
          initialSelection: _removeSelection!,
          onClose: () => setState(() => _removeSelection = null),
          onSave: (k, key, q, r) {
            bloc.add(
              SaleSentItemAdjusted(
                kind: k,
                key: key,
                qty: q,
                reason: r,
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
            bloc.add(const SaleTableClosed());
            setState(() => _showCloseConfirm = false);
            widget.onBackToTables();
          },
        ),
      if (modalBill != null)
        ReceiptModal(
          shop: state.posState.shop,
          bill: modalBill,
          fresh: isSettled,
          staff: widget.staff,
          allowCashierVoid: true,
          tableSummary: buildTableSummarySlip(
            state.posState,
            tb.id,
            now: state.now,
          ),
          doneLabel:
              isSettled &&
                  state.effectiveTiming == 'after' &&
                  state.openTable != null
              ? 'เสร็จสิ้น · เก็บโต๊ะ'
              : null,
          onPrint: () => showAppToast(context, 'ส่งพิมพ์ใบเสร็จแล้ว (จำลอง)'),
          onVoid: (reason) {
            bloc.add(
              SaleSettledBillVoided(
                staff: widget.staff,
                billId: modalBill.id,
                reason: reason,
              ),
            );
            setState(() => _showPosSlipModal = false);
          },
          onVoidSubBill: (billId, r) => bloc.add(
            SaleSettledBillVoided(
              staff: widget.staff,
              billId: billId,
              reason: r,
            ),
          ),
          onCancelTable: () {
            bloc.add(const SaleOpenTableCancelled());
            setState(() => _showPosSlipModal = false);
            widget.onBackToTables();
          },
          onDone: () {
            if (!isSettled) {
              setState(() => _showPosSlipModal = false);
              return;
            }
            if (state.effectiveTiming == 'after' &&
                state.openTable != null &&
                state.due == 0) {
              bloc.add(const SaleTableClosed());
            }
            bloc.add(const SaleReceiptDismissed());
            widget.onBackToTables();
          },
        ),
    ];
  }
}
