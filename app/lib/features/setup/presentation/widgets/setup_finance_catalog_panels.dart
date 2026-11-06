import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:flutter/material.dart';

export 'package:app/features/setup/presentation/widgets/setup_ing_modals.dart'
    show SetupJsonSnapshotModal;

/// Callback signature for opening the create/edit modal of a catalog section.
typedef SetupEditCallback = void Function(String section, Object? item);

/// Callback signature for requesting deletion of a catalog item.
typedef SetupDeleteCallback = void Function(
  String section,
  String id,
  String name,
);

/// Secondary catalog tables for `/setup` (`staff`, `payments`, `fixedCosts`,
/// `expenseTypes`).
class SetupFinanceCatalogPanel extends StatelessWidget {
  const new({
    required this.state,
    required this.cubit,
    required this.onOpenEditor,
    required this.onRequestDelete,
    this.staffRole = 'owner',
    super.key,
  });

  final SetupState state;
  final SetupCubit cubit;
  final SetupEditCallback onOpenEditor;
  final SetupDeleteCallback onRequestDelete;
  final String staffRole;

  DataTableCol<T> _col<T>(
    String key,
    String label,
    String Function(T) textOf, {
    int flex = 3,
  }) => DataTableCol<T>(
    key: key,
    label: label,
    flex: flex,
    cellBuilder: (_, item) => Text(textOf(item)),
  );

  Widget _activeSwitchCell({
    required bool active,
    required String onText,
    required String offText,
    required String semanticLabel,
    required ValueChanged<bool>? onChanged,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppSwitch(
        value: active,
        semanticLabel: semanticLabel,
        onChanged: onChanged,
      ),
      const SizedBox(width: AppDimensions.space2),
      Pill(
        tone: active ? PillTone.green : PillTone.neutral,
        child: Text(active ? onText : offText),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final s = state.posState;
    return switch (state.activeTab) {
      'staff' => CrudSectionShell<StaffMember>(
        title: 'พนักงานและสิทธิ์',
        desc: 'รหัส PIN 4 หลักสำหรับเข้าใช้งานและสิทธิ์ตามตำแหน่ง',
        addButtonKey: const ValueKey('setup-add-staff-btn'),
        addLabel: 'เพิ่มพนักงาน',
        canWrite: staffRole == 'owner',
        lockedReason: 'เฉพาะเจ้าของร้านเท่านั้นที่เพิ่ม แก้ไข หรือลบพนักงานได้',
        summaryBanner: StatsGroup(
          children: [
            Stat(
              label: 'พนักงานทั้งหมด',
              value: '${s.staff.length} คน',
              sub: 'มีบัญชีเข้าใช้งานในระบบ',
            ),
            Stat(
              label: 'เปิดใช้งานอยู่',
              value: '${s.staff.where((u) => u.active).length} คน',
              sub: 'เข้าสู่ระบบด้วยรหัส PIN ได้',
            ),
            Stat(
              label: 'เจ้าของร้าน / ผู้จัดการ',
              value: '${s.staff.where((u) => u.role != 'cashier').length} คน',
              sub: 'มีสิทธิ์จัดการรายงานและสต็อก',
            ),
          ],
        ),
        rows: state.filteredStaff,
        itemNameOf: (u) => u.name,
        onAdd: () => onOpenEditor('staff', null),
        onEdit: (u) => onOpenEditor('staff', u),
        onDelete: (u) => onRequestDelete('staff', u.id, u.name),
        columns: [
          _col('name', 'ชื่อพนักงาน', (u) => u.name),
          _col('role', 'ตำแหน่ง', (u) => kRoles[u.role] ?? u.role),
          _col('pin', 'รหัส PIN', (_) => '••••', flex: 2),
          DataTableCol(
            key: 'active',
            label: 'สถานะ',
            flex: 3,
            cellBuilder: (_, u) => _activeSwitchCell(
              active: u.active,
              onText: 'ใช้งานอยู่',
              offText: 'ระงับ',
              semanticLabel: 'ใช้งาน ${u.name}',
              onChanged: staffRole == 'owner'
                  ? (on) => cubit.toggleStaffActive(
                      u,
                      active: on,
                      actorRole: staffRole,
                    )
                  : null,
            ),
          ),
        ],
      ),
      'payments' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CrudSectionShell<PaymentMethod>(
            title: 'ช่องทางชำระเงิน',
            desc: 'วิธีรับเงินที่แสดงในหน้าขายและสรุปยอดกะการขาย',
            addButtonKey: const ValueKey('setup-add-payments-btn'),
            addLabel: 'เพิ่มช่องทาง',
            headerPills: [
              Pill(
                tone: PillTone.green,
                child: Text(
                  'เปิดใช้ ${s.payments.where((p) => p.active).length}'
                  '/${s.payments.length}',
                ),
              ),
            ],
            rows: state.filteredPayments,
            itemNameOf: (p) => p.name,
            onAdd: () => onOpenEditor('payments', null),
            onEdit: (p) => onOpenEditor('payments', p),
            onDelete: (p) => onRequestDelete('payments', p.id, p.name),
            columns: [
              _col('name', 'ชื่อช่องทาง', (p) => p.name),
              _col(
                'type',
                'ประเภทการรับเงิน',
                (p) => kPayTypes[p.type] ?? p.type,
              ),
              DataTableCol(
                key: 'active',
                label: 'สถานะ',
                flex: 3,
                cellBuilder: (_, p) => _activeSwitchCell(
                  active: p.active,
                  onText: 'เปิดใช้',
                  offText: 'ปิด',
                  semanticLabel: 'เปิดใช้ ${p.name}',
                  onChanged: (on) => cubit.togglePaymentActive(p, active: on),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space5),
          CrudSectionShell<BankAccountItem>(
            title: 'บัญชีธนาคารสำหรับรับเงินโอน',
            desc:
                'เพิ่มเลขที่บัญชีธนาคารของร้านได้มากกว่า 1 บัญชี '
                'เพื่อเลือกบัญชีรับโอนในหน้าขายและกระทบยอดทางบัญชี',
            addButtonKey: const ValueKey('setup-add-bankAccounts-btn'),
            addLabel: 'เพิ่มบัญชีธนาคาร',
            headerPills: [
              Pill(
                tone: PillTone.green,
                child: Text(
                  'เปิดใช้ ${s.shop.activeBankAccounts.length}'
                  '/${s.shop.bankAccounts.length}',
                ),
              ),
            ],
            rows: state.filteredBankAccounts,
            itemNameOf: (b) => b.shortLabel,
            onAdd: () => onOpenEditor('bankAccounts', null),
            onEdit: (b) => onOpenEditor('bankAccounts', b),
            onDelete: (b) =>
                onRequestDelete('bankAccounts', b.id, b.shortLabel),
            columns: [
              _col('bankName', 'ธนาคาร', (b) => b.bankName),
              _col('accountNo', 'เลขที่บัญชี', (b) => b.accountNo),
              _col('accountName', 'ชื่อบัญชี', (b) => b.accountName),
              DataTableCol(
                key: 'active',
                label: 'สถานะ',
                flex: 3,
                cellBuilder: (_, b) => _activeSwitchCell(
                  active: b.active,
                  onText: 'เปิดใช้',
                  offText: 'ปิด',
                  semanticLabel: 'เปิดใช้ ${b.shortLabel}',
                  onChanged: (on) =>
                      cubit.toggleBankAccountActive(b, active: on),
                ),
              ),
            ],
          ),
        ],
      ),
      'fixedCosts' => CrudSectionShell<FixedCostItem>(
        title: 'ค่าใช้จ่ายคงที่รายเดือน',
        desc:
            'ค่าเช่า ค่าไฟ เงินเดือน ฯลฯ นำไปหารเฉลี่ยรายวันเพื่อคิดกำไรสุทธิ',
        addButtonKey: const ValueKey('setup-add-fixedCosts-btn'),
        addLabel: 'เพิ่มค่าใช้จ่ายคงที่',
        summaryBanner: StatsGroup(
          children: [
            Stat(
              label: 'รวมค่าคงที่ต่อเดือน (ที่เปิดคิด)',
              value: baht(state.totalMonthlyFixedCost),
              sub: '${s.fixedCosts.where((f) => f.active).length} รายการ',
            ),
            Stat(
              label: 'เฉลี่ยต่อวันที่เปิดร้าน',
              value: baht(state.dailyFixedCost),
              sub: s.shop.fixedCostDivisor == 'calendar'
                  ? 'ตามปฏิทิน (${state.effectiveFixedCostDivisor} วัน)'
                  : 'หาร ${s.shop.openDaysPerMonth} วัน/เดือน',
            ),
          ],
        ),
        rows: state.filteredFixedCosts,
        itemNameOf: (f) => f.name,
        onAdd: () => onOpenEditor('fixedCosts', null),
        onEdit: (f) => onOpenEditor('fixedCosts', f),
        onDelete: (f) => onRequestDelete('fixedCosts', f.id, f.name),
        columns: [
          _col('name', 'รายการค่าใช้จ่าย', (f) => f.name, flex: 4),
          _col('amount', 'ยอดต่อเดือน', (f) => baht(f.amount), flex: 2),
          DataTableCol(
            key: 'active',
            label: 'นำไปคำนวณ',
            flex: 3,
            cellBuilder: (_, f) => _activeSwitchCell(
              active: f.active,
              onText: 'คิดรวม',
              offText: 'ไม่คิด',
              semanticLabel: 'คิดรวม ${f.name}',
              onChanged: (on) => cubit.toggleFixedCostActive(f, active: on),
            ),
          ),
        ],
      ),
      _ => CrudSectionShell<ExpenseType>(
        title: 'ประเภทค่าใช้จ่ายรายวัน',
        desc:
            'หมวดหมู่ค่าใช้จ่ายดำเนินงานที่ใช้บันทึกในหน้าสต็อก'
            'และค่าใช้จ่ายรายวัน',
        addButtonKey: const ValueKey('setup-add-expenseTypes-btn'),
        addLabel: 'เพิ่มประเภท',
        headerPills: [
          Pill(child: Text('ทั้งหมด ${s.expenseTypes.length} หมวด')),
        ],
        rows: state.filteredExpenseTypes,
        itemNameOf: (e) => e.name,
        onAdd: () => onOpenEditor('expenseTypes', null),
        onEdit: (e) => onOpenEditor('expenseTypes', e),
        onDelete: (e) => onRequestDelete('expenseTypes', e.id, e.name),
        columns: [_col('name', 'ชื่อประเภทค่าใช้จ่าย', (e) => e.name, flex: 6)],
      ),
    };
  }
}
