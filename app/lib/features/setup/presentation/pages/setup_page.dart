import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:app/features/setup/presentation/widgets/setup_catalog_panels.dart';
import 'package:app/features/setup/presentation/widgets/setup_costing_demo_panels.dart';
import 'package:app/features/setup/presentation/widgets/setup_crud_modals.dart';
import 'package:app/features/setup/presentation/widgets/setup_nav_sidebar.dart';
import 'package:app/features/setup/presentation/widgets/setup_shop_costing_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:app/features/setup/presentation/widgets/setup_nav_sidebar.dart'
    show SetupThemeSection;

/// Full store configuration page (`/setup`, driven by [SetupCubit]).
class SetupPage extends StatefulWidget {
  const new({
    this.repo,
    this.initialTab = 'shop',
    this.staffRole = 'owner',
    this.currentStaffId,
    super.key,
  });

  final PosRepository? repo;
  final String initialTab;
  final String staffRole;
  final String? currentStaffId;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  (String section, Object? item)? _editing;
  (String section, String id, String name)? _deleting;
  bool? _jsonModalIsImport;
  String? _demoConfirmKind;

  SetupCubit? _maybeCubit(BuildContext context) {
    try {
      return context.read<SetupCubit>();
    } on Object {
      return null;
    }
  }

  Widget _overlay(BuildContext context, Widget child) => Positioned.fill(
    child: ColoredBox(
      color: context.tokens.scrim,
      child: Center(child: child),
    ),
  );

  Widget _buildDemoConfirm(SetupCubit cubit) {
    final kind = _demoConfirmKind!;
    final openCnt = cubit.state.posState.openTables.length;
    final openWarn = openCnt > 0
        ? ' (รวมถึงโต๊ะที่กำลังเปิดอยู่ $openCnt โต๊ะ)'
        : '';
    final (title, text, yesLabel, danger) = switch (kind) {
      'clear' => (
        'เริ่มข้อมูลรายวันใหม่ (0 บิล)?',
        'บิลขาย กะ และสต็อกรายวันทั้งหมด$openWarnจะถูกล้างเป็นศูนย์ '
            '(เมนูและตั้งค่าร้านยังอยู่ครบ)',
        'เริ่มรายวันใหม่',
        true,
      ),
      'advance' => (
        'จำลองข้ามไปวันถัดไป (+1 วัน)?',
        'ระบบจะเลื่อนประวัติบิล กะ และสต็อกย้อนหลังไป 1 วัน '
            'เพื่อเริ่มจำลองวันถัดไป',
        'ข้ามไปวันถัดไป',
        false,
      ),
      _ => (
        'รีเซ็ตข้อมูลตัวอย่าง 30 วัน?',
        'บิลขาย กะ และสต็อกที่ลองแก้ไขไว้จะถูกล้างและสร้างใหม่',
        'รีเซ็ตข้อมูล',
        true,
      ),
    };
    return Confirm(
      title: title,
      text: text,
      yesLabel: yesLabel,
      danger: danger,
      onNo: () => setState(() => _demoConfirmKind = null),
      onYes: () {
        setState(() => _demoConfirmKind = null);
        switch (kind) {
          case 'clear':
            cubit.clearDailyTransactions();
          case 'advance':
            cubit.advanceSimulationDay();
          default:
            cubit.resetDemoTransactions();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = _maybeCubit(context);
    if (existing == null && widget.repo != null) {
      return BlocProvider(
        create: (_) => SetupCubit(widget.repo!, initialTab: widget.initialTab),
        child: Builder(builder: _buildConsumer),
      );
    }
    return _buildConsumer(context);
  }

  Widget _buildConsumer(
    BuildContext context,
  ) => BlocConsumer<SetupCubit, SetupState>(
    listenWhen: (prev, curr) =>
        curr.toastMessage.isNotEmpty && prev.toastMessage != curr.toastMessage,
    listener: (context, state) {
      showAppToast(context, state.toastMessage);
      context.read<SetupCubit>().clearToast();
    },
    builder: (context, state) {
      final cubit = context.read<SetupCubit>();
      final s = state.posState;

      final detail = switch (state.activeTab) {
        'shop' => SetupShopPanel(
          shop: s.shop,
          isSaving: state.isSaving,
          onSave: cubit.saveShop,
        ),
        'costing' => SetupCostingPanel(
          shop: s.shop,
          totalMonthlyFixedCost: state.totalMonthlyFixedCost,
          isSaving: state.isSaving,
          onSave: cubit.saveCosting,
        ),
        'theme' => const SetupThemeSection(),
        'demo' => SetupDemoPanel(
          posState: s,
          onExportJson: () => setState(() => _jsonModalIsImport = false),
          onImportJson: () => setState(() => _jsonModalIsImport = true),
          onRequestReset: () => setState(() => _demoConfirmKind = 'reset'),
          onClearDaily: () => setState(() => _demoConfirmKind = 'clear'),
          onAdvanceDay: () => setState(() => _demoConfirmKind = 'advance'),
        ),
        _ => SetupCatalogPanel(
          state: state,
          cubit: cubit,
          staffRole: widget.staffRole,
          onOpenEditor: (sec, it) => setState(() => _editing = (sec, it)),
          onRequestDelete: (sec, id, name) {
            final canDel = cubit.checkCanDelete(
              section: sec,
              id: id,
              currentStaffId: widget.currentStaffId,
            );
            if (canDel) setState(() => _deleting = (sec, id, name));
          },
        ),
      };

      return Stack(
        children: [
          SingleChildScrollView(
            key: const ValueKey('setup-page'),
            padding: const EdgeInsets.all(AppDimensions.space4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SetupNavSidebar(state: state, onSelectTab: cubit.setTab),
                    const SizedBox(height: AppDimensions.space4),
                    detail,
                  ],
                ),
              ),
            ),
          ),
          if (_editing != null)
            _overlay(
              context,
              SingleChildScrollView(
                child: SetupCrudEditorModal(
                  section: _editing!.$1,
                  initialItem: _editing!.$2,
                  cubit: cubit,
                  staffRole: widget.staffRole,
                  onClose: () => setState(() => _editing = null),
                ),
              ),
            ),
          if (_deleting != null)
            _overlay(
              context,
              Confirm(
                title: 'ลบ "${_deleting!.$3}"?',
                text: 'ลบแล้วกู้คืนไม่ได้ ข้อมูลในบิลเก่ายังอยู่ครบ',
                yesLabel: 'ลบรายการ',
                danger: true,
                onNo: () => setState(() => _deleting = null),
                onYes: () {
                  final d = _deleting!;
                  setState(() => _deleting = null);
                  cubit.deleteItem(
                    section: d.$1,
                    id: d.$2,
                    currentStaffId: widget.currentStaffId,
                  );
                },
              ),
            ),
          if (state.guardModalMessage.isNotEmpty)
            _overlay(
              context,
              Modal(
                title: 'ไม่สามารถดำเนินการได้',
                onClose: cubit.clearGuardModal,
                footer: [
                  Btn(
                    kind: BtnKind.primary,
                    label: 'เข้าใจแล้ว',
                    onPressed: cubit.clearGuardModal,
                  ),
                ],
                child: Text(state.guardModalMessage),
              ),
            ),
          if (_jsonModalIsImport != null)
            _overlay(
              context,
              SingleChildScrollView(
                child: SetupJsonSnapshotModal(
                  isImport: _jsonModalIsImport!,
                  initialJson: _jsonModalIsImport! ? '' : cubit.exportJson(),
                  onClose: () => setState(() => _jsonModalIsImport = null),
                  onImport: (raw) {
                    final ok = cubit.importJson(raw);
                    if (ok) setState(() => _jsonModalIsImport = null);
                  },
                ),
              ),
            ),
          if (_demoConfirmKind != null)
            _overlay(context, _buildDemoConfirm(cubit)),
        ],
      );
    },
  );
}
