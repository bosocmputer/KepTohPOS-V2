import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:flutter/material.dart';

/// Secondary CRUD editor modal for `tables`, `staff`, `payments`,
/// `fixedCosts`, and `expenseTypes`.
class SetupSecondaryEditorModal extends StatefulWidget {
  const new({
    required this.section,
    required this.cubit,
    required this.onClose,
    this.initialItem,
    this.staffRole = 'owner',
    super.key,
  });

  final String section;
  final Object? initialItem;
  final SetupCubit cubit;
  final String staffRole;
  final VoidCallback onClose;

  @override
  State<SetupSecondaryEditorModal> createState() =>
      _SetupSecondaryEditorModalState();
}

class _SetupSecondaryEditorModalState extends State<SetupSecondaryEditorModal> {
  String _err = '';
  late DiningTable _table;
  late StaffMember _staff;
  late PaymentMethod _pay;
  late BankAccountItem _bank;
  late FixedCostItem _fixed;
  late ExpenseType _expType;

  bool get _isEdit => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    final it = widget.initialItem;
    const u = nextSetupUid;
    _table = it is DiningTable
        ? it
        : DiningTable(id: u('t'), name: '', seats: 4, zone: 'ในร้าน');
    _staff = it is StaffMember
        ? it
        : StaffMember(id: u('st'), name: '', role: 'cashier', pin: '');
    _pay = it is PaymentMethod
        ? it
        : PaymentMethod(id: u('pm'), name: '', type: 'qr');
    _bank = it is BankAccountItem
        ? it
        : BankAccountItem(
            id: u('ba'),
            bankName: '',
            accountNo: '',
            accountName: '',
          );
    _fixed = it is FixedCostItem
        ? it
        : FixedCostItem(id: u('fx'), name: '', amount: 0);
    _expType = it is ExpenseType ? it : ExpenseType(id: u('et'), name: '');
  }

  void _submit() {
    final c = widget.cubit;
    final res = switch (widget.section) {
      'tables' => c.upsertTable(_table),
      'staff' => c.upsertStaff(_staff, actorRole: widget.staffRole),
      'payments' => c.upsertPayment(_pay),
      'bankAccounts' => c.upsertBankAccount(_bank),
      'fixedCosts' => c.upsertFixedCost(_fixed),
      'expenseTypes' => c.upsertExpenseType(_expType),
      _ => const SetupCrudResult.failure('ไม่รู้จักหมวดข้อมูล'),
    };
    res.ok ? widget.onClose() : setState(() => _err = res.message);
  }

  Widget _row(Widget left, Widget right) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimensions.space3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppDimensions.space3),
        Expanded(child: right),
      ],
    ),
  );

  Widget _col(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );

  Widget _txt(
    String label,
    String val,
    ValueChanged<String> apply, {
    String? hint,
    String placeholder = '',
    bool numKey = false,
  }) => Field(
    label: label,
    hint: hint,
    child: AppTextInput(
      value: val,
      placeholder: placeholder,
      keyboardType: numKey ? TextInputType.number : null,
      onChanged: (v) => setState(() => apply(v)),
    ),
  );

  Widget _drop(
    String label,
    String val,
    Map<String, String> map,
    ValueChanged<String> apply,
  ) => Field(
    label: label,
    child: Dropdown<String>(
      label: label,
      value: val,
      options: [
        for (final e in map.entries)
          DropdownOption(value: e.key, label: e.value),
      ],
      onChanged: (v) => setState(() => apply(v)),
    ),
  );

  Widget _sw(bool val, String label, ValueChanged<bool> apply) => AppSwitch(
    value: val,
    label: label,
    onChanged: (on) => setState(() => apply(on)),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pfx = _isEdit ? 'แก้ไข' : 'เพิ่ม';
    final (title, sub) = switch (widget.section) {
      'tables' => ('$pfxโต๊ะในร้าน', 'กำหนดชื่อโต๊ะ จำนวนที่นั่ง และโซน'),
      'staff' => ('$pfxพนักงาน', 'กำหนดชื่อ ตำแหน่ง และรหัส PIN 4 หลัก'),
      'payments' => ('$pfxช่องทางชำระเงิน', 'กำหนดชื่อและประเภทการรับเงิน'),
      'bankAccounts' => (
        '$pfxบัญชีธนาคาร',
        'กำหนดธนาคาร เลขที่บัญชี และชื่อบัญชีสำหรับรับเงินโอน',
      ),
      'fixedCosts' => ('$pfxค่าใช้จ่ายคงที่รายเดือน', 'กำหนดยอดรายเดือน'),
      _ => ('$pfxประเภทค่าใช้จ่ายรายวัน', 'กำหนดชื่อหมวดค่าใช้จ่ายรายวัน'),
    };

    return Modal(
      title: title,
      sub: sub,
      onClose: widget.onClose,
      footer: [
        Btn(label: 'ยกเลิก', onPressed: widget.onClose),
        Btn(
          key: const ValueKey('setup-modal-save-btn'),
          kind: BtnKind.primary,
          icon: 'check',
          label: 'บันทึก',
          onPressed: _submit,
        ),
      ],
      child: _col([
        switch (widget.section) {
          'tables' => _col([
            _row(
              _txt('ชื่อโต๊ะ *', _table.name, (v) {
                _table = _table.copyWith(name: v);
              }, placeholder: 'เช่น A1, B1'),
              _txt(
                'จำนวนที่นั่ง',
                _table.seats.toString(),
                (v) => _table = _table.copyWith(seats: int.tryParse(v) ?? 4),
                numKey: true,
              ),
            ),
            _txt('โซนที่นั่ง', _table.zone, (v) {
              _table = _table.copyWith(zone: v);
            }, placeholder: 'เช่น ในร้าน, ริมระเบียง, ห้องแอร์'),
          ]),
          'staff' => _col([
            _row(
              _txt('ชื่อพนักงาน *', _staff.name, (v) {
                _staff = _staff.copyWith(name: v);
              }, placeholder: 'เช่น น้องมุก'),
              _drop(
                'ตำแหน่งและสิทธิ์การใช้งาน',
                _staff.role,
                kRoles,
                (v) => _staff = _staff.copyWith(role: v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space3),
              child: _txt(
                'รหัส PIN (ตัวเลข 4 หลัก) *',
                _staff.pin,
                (v) => _staff = _staff.copyWith(pin: v.trim()),
                placeholder: 'เช่น 1234',
                hint: 'ต้องไม่ซ้ำกับพนักงานคนอื่นในร้าน',
                numKey: true,
              ),
            ),
            _sw(
              _staff.active,
              'เปิดใช้งานบัญชีสำหรับเข้าสู่ระบบด้วยรหัส PIN',
              (on) => _staff = _staff.copyWith(active: on),
            ),
          ]),
          'payments' => _col([
            _row(
              _txt('ชื่อช่องทางชำระเงิน *', _pay.name, (v) {
                _pay = _pay.copyWith(name: v);
              }, placeholder: 'เช่น พร้อมเพย์ร้าน / เงินสด'),
              _drop(
                'ประเภทการรับเงิน',
                _pay.type,
                kPayTypes,
                (v) => _pay = _pay.copyWith(type: v),
              ),
            ),
            _sw(
              _pay.active,
              'เปิดใช้งานในหน้าขายและสรุปกะการขาย',
              (on) => _pay = _pay.copyWith(active: on),
            ),
          ]),
          'bankAccounts' => _col([
            _row(
              _txt('ชื่อธนาคาร *', _bank.bankName, (v) {
                _bank = _bank.copyWith(bankName: v);
              }, placeholder: 'เช่น ธนาคารกสิกรไทย'),
              _txt('เลขที่บัญชี *', _bank.accountNo, (v) {
                _bank = _bank.copyWith(accountNo: v);
              }, placeholder: 'เช่น 123-4-56789-0'),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space3),
              child: _txt('ชื่อบัญชี', _bank.accountName, (v) {
                _bank = _bank.copyWith(accountName: v);
              }, placeholder: 'เช่น ร้านหมูกระทะลุงหมี'),
            ),
            _sw(
              _bank.active,
              'เปิดใช้งานสำหรับรับเงินโอนในหน้าขาย',
              (on) => _bank = _bank.copyWith(active: on),
            ),
          ]),
          'fixedCosts' => _col([
            _row(
              _txt('รายการค่าใช้จ่ายคงที่ *', _fixed.name, (v) {
                _fixed = _fixed.copyWith(name: v);
              }, placeholder: 'เช่น ค่าเช่าร้าน / ค่าไฟฟ้า'),
              _txt(
                'ยอดต่อเดือน (บาท) *',
                bahtInputText(_fixed.amount),
                (v) => _fixed = _fixed.copyWith(amount: parseBaht(v)),
                numKey: true,
              ),
            ),
            _sw(
              _fixed.active,
              'นำไปรวมคำนวณกำไรสุทธิรายวัน',
              (on) => _fixed = _fixed.copyWith(active: on),
            ),
          ]),
          _ => _txt('ชื่อประเภทค่าใช้จ่ายรายวัน *', _expType.name, (v) {
            _expType = _expType.copyWith(name: v);
          }, placeholder: 'เช่น น้ำแข็ง / แก๊สหุงต้ม / ค่าแรงรายวัน'),
        },
        if (_err.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.space3),
          Text(
            _err,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: t.danger, fontWeight: FontWeight.w600),
          ),
        ],
      ]),
    );
  }
}
