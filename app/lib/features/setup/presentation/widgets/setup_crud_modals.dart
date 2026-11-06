import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:app/features/setup/presentation/widgets/setup_ing_modals.dart';
import 'package:app/features/setup/presentation/widgets/setup_secondary_modals.dart';
import 'package:flutter/material.dart';

export 'package:app/features/setup/presentation/widgets/setup_ing_modals.dart'
    show SetupJsonSnapshotModal;
export 'package:app/features/setup/presentation/widgets/setup_secondary_modals.dart';

/// Modal dispatcher for creating or editing a catalog item in `/setup`.
class SetupCrudEditorModal extends StatefulWidget {
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
  final VoidCallback onClose;
  final String staffRole;

  @override
  State<SetupCrudEditorModal> createState() => _SetupCrudEditorModalState();
}

class _SetupCrudEditorModalState extends State<SetupCrudEditorModal> {
  String _err = '';
  late PackageItem _pkg;
  late AddonItem _addon;

  bool get _isEdit => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    final it = widget.initialItem;
    _pkg = it is PackageItem
        ? it
        : PackageItem(
            id: nextSetupUid('pk'),
            name: '',
            adultPrice: 199,
            childPrice: 99,
          );
    _addon = it is AddonItem
        ? it.copyWith()
        : AddonItem(
            id: nextSetupUid('ad'),
            name: '',
            category: 'เครื่องดื่ม',
            price: 25,
            cost: 12,
            stock: 24,
          );
  }

  void _submit() {
    final c = widget.cubit;
    final res = widget.section == 'packages'
        ? c.upsertPackage(_pkg)
        : c.upsertAddon(_addon);
    if (res.ok) {
      widget.onClose();
    } else {
      setState(() => _err = res.message);
    }
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

  @override
  Widget build(BuildContext context) {
    if (widget.section == 'ingredients' || widget.section == 'suppliers') {
      return SetupIngredientSupplierModal(
        section: widget.section,
        initialItem: widget.initialItem,
        cubit: widget.cubit,
        onClose: widget.onClose,
      );
    }
    if (widget.section != 'packages' && widget.section != 'addons') {
      return SetupSecondaryEditorModal(
        section: widget.section,
        initialItem: widget.initialItem,
        cubit: widget.cubit,
        staffRole: widget.staffRole,
        onClose: widget.onClose,
      );
    }

    final t = context.tokens;
    final isPkg = widget.section == 'packages';
    final title = isPkg
        ? '${_isEdit ? "แก้ไข" : "เพิ่ม"}แพ็กเกจบุฟเฟต์'
        : '${_isEdit ? "แก้ไข" : "เพิ่ม"}สินค้าขายเสริม';
    final sub = isPkg
        ? 'กำหนดราคาผู้ใหญ่ ราคาเด็ก และเวลาจำกัดสำหรับการเปิดโต๊ะ'
        : 'กำหนดราคาขาย ต้นทุนต่อหน่วย และสต็อกเริ่มต้นของสินค้าเสริม';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPkg) _buildPackageFields() else _buildAddonFields(),
          if (_err.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space3),
            Text(
              _err,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: t.danger, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPackageFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _row(
        _txt(
          'ชื่อแพ็กเกจ *',
          _pkg.name,
          (v) => _pkg = _pkg.copyWith(name: v),
          placeholder: 'เช่น บุฟเฟต์หมูกระทะ 199',
        ),
        _txt(
          'เวลาจำกัด (นาที)',
          _pkg.timeLimit.toString(),
          (v) => _pkg = _pkg.copyWith(timeLimit: int.tryParse(v) ?? 0),
          hint: 'ใส่ 0 = ไม่จำกัดเวลา',
          numKey: true,
        ),
      ),
      _row(
        _txt(
          'ราคาผู้ใหญ่ (บาท) *',
          fmtQ(_pkg.adultPrice),
          (v) => _pkg = _pkg.copyWith(adultPrice: double.tryParse(v) ?? 0),
          numKey: true,
        ),
        _txt(
          'ราคาเด็ก (บาท) *',
          fmtQ(_pkg.childPrice),
          (v) => _pkg = _pkg.copyWith(childPrice: double.tryParse(v) ?? 0),
          numKey: true,
        ),
      ),
      _row(
        _txt(
          'เกณฑ์ราคาเด็ก',
          _pkg.childRule,
          (v) => _pkg = _pkg.copyWith(childRule: v),
          placeholder: 'เช่น สูง 100–130 ซม.',
        ),
        _txt(
          'เกณฑ์ทานฟรี',
          _pkg.freeRule,
          (v) => _pkg = _pkg.copyWith(freeRule: v),
          placeholder: 'เช่น สูงต่ำกว่า 100 ซม.',
        ),
      ),
      AppSwitch(
        value: _pkg.active,
        label: 'เปิดขายในหน้าขายทันที',
        onChanged: (on) => setState(() => _pkg = _pkg.copyWith(active: on)),
      ),
    ],
  );

  Widget _buildAddonFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _row(
        _txt(
          'ชื่อสินค้า *',
          _addon.name,
          (v) => _addon = _addon.copyWith(name: v),
          placeholder: 'เช่น น้ำอัดลม 1.25 ลิตร',
        ),
        _txt(
          'หมวดหมู่',
          _addon.category,
          (v) => _addon = _addon.copyWith(category: v),
          placeholder: 'เช่น เครื่องดื่ม / ของทานเล่น',
        ),
      ),
      _row(
        _txt(
          'ราคาขาย (บาท) *',
          fmtQ(_addon.price),
          (v) => _addon = _addon.copyWith(price: double.tryParse(v) ?? 0),
          numKey: true,
        ),
        _txt(
          'ต้นทุนต่อหน่วย (บาท)',
          fmtQ(_addon.cost),
          (v) => _addon = _addon.copyWith(cost: double.tryParse(v) ?? 0),
          numKey: true,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.space3),
        child: _txt(
          'จำนวนคงเหลือในสต็อก',
          _addon.stock.toString(),
          (v) => _addon = _addon.copyWith(stock: int.tryParse(v) ?? 0),
          hint: 'ตัดสต็อกอัตโนมัติเมื่อรับชำระเงิน',
          numKey: true,
        ),
      ),
      AppSwitch(
        value: _addon.active,
        label: 'เปิดขายในหน้าขายทันที',
        onChanged: (on) => setState(() => _addon = _addon.copyWith(active: on)),
      ),
    ],
  );
}
