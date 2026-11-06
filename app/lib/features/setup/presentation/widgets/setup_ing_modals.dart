import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:flutter/material.dart';

export 'package:app/features/setup/presentation/widgets/setup_finance_catalog_panels.dart'
    show SetupJsonSnapshotModal;

const List<String> _kUnits = [
  'กก.',
  'กรัม',
  'ลิตร',
  'แพ็ค',
  'ฟอง',
  'ถุง',
  'ชิ้น',
  'ขวด',
];

/// Modal for creating or editing `ingredients` and `suppliers` in `/setup`.
class SetupIngredientSupplierModal extends StatefulWidget {
  const new({
    required this.section,
    required this.cubit,
    required this.onClose,
    this.initialItem,
    super.key,
  });

  final String section;
  final Object? initialItem;
  final SetupCubit cubit;
  final VoidCallback onClose;

  @override
  State<SetupIngredientSupplierModal> createState() =>
      _SetupIngredientSupplierModalState();
}

class _SetupIngredientSupplierModalState
    extends State<SetupIngredientSupplierModal> {
  String _err = '';
  late IngredientItem _ing;
  late SupplierItem _sup;

  bool get _isEdit => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    final it = widget.initialItem;
    final s = widget.cubit.state.posState;
    _ing = it is IngredientItem
        ? it
        : IngredientItem(
            id: nextSetupUid('i'),
            name: '',
            unit: 'กก.',
            lastCost: 100,
            par: 5,
            supplierId: s.suppliers.firstOrNull?.id ?? '',
            category: 'วัตถุดิบ',
            use: 1,
          );
    _sup = it is SupplierItem
        ? it
        : SupplierItem(id: nextSetupUid('sup'), name: '');
  }

  void _submit() {
    final c = widget.cubit;
    final res = widget.section == 'ingredients'
        ? c.upsertIngredient(_ing)
        : c.upsertSupplier(_sup);
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
    int lines = 1,
    bool numKey = false,
    String placeholder = '',
  }) => Field(
    label: label,
    child: AppTextInput(
      value: val,
      maxLines: lines,
      placeholder: placeholder,
      keyboardType: numKey ? TextInputType.number : null,
      onChanged: (v) => setState(() => apply(v)),
    ),
  );

  Widget _dd(
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isIng = widget.section == 'ingredients';
    return Modal(
      title:
          '${_isEdit ? "แก้ไข" : "เพิ่ม"}'
          '${isIng ? "วัตถุดิบ" : "แหล่งซื้อของ"}',
      sub: isIng
          ? 'กำหนดหน่วยนับ ที่เก็บ ความถี่นับสต็อก และจุดเตือนสั่งซื้อ (Par)'
          : 'บันทึกชื่อตลาดสด ร้านส่ง หรือคู่ค้าสำหรับอ้างอิงในใบรับของ',
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
          if (isIng) _buildIngredientFields() else _buildSupplierFields(),
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

  Widget _buildIngredientFields() {
    final sups = widget.cubit.state.posState.suppliers;
    final unitMap = {for (final u in _kUnits) u: u};
    final catMap = {
      'วัตถุดิบ': 'วัตถุดิบ',
      'วัสดุสิ้นเปลือง': 'วัสดุสิ้นเปลือง',
    };
    final supMap = {for (final s in sups) s.id: s.name};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          _txt(
            'ชื่อวัตถุดิบ *',
            _ing.name,
            (v) => _ing = _ing.copyWith(name: v),
            placeholder: 'เช่น หมูสามชั้นสไลซ์',
          ),
          _dd(
            'หน่วยนับ',
            _kUnits.contains(_ing.unit) ? _ing.unit : _kUnits.first,
            unitMap,
            (v) => _ing = _ing.copyWith(unit: v),
          ),
        ),
        _row(
          _dd(
            'ประเภทวัตถุดิบ',
            _ing.category.isEmpty ? 'วัตถุดิบ' : _ing.category,
            catMap,
            (v) => _ing = _ing.copyWith(category: v),
          ),
          _dd(
            'สถานที่จัดเก็บ',
            _ing.location,
            kLocations,
            (v) => _ing = _ing.copyWith(location: v),
          ),
        ),
        _row(
          _dd(
            'ความถี่นับสต็อก',
            _ing.countFreq,
            kCountFreqs,
            (v) => _ing = _ing.copyWith(countFreq: v),
          ),
          _txt(
            'ราคาซื้อล่าสุด (บาท/หน่วย)',
            fmtQ(_ing.lastCost),
            (v) => _ing = _ing.copyWith(lastCost: double.tryParse(v) ?? 0),
            numKey: true,
          ),
        ),
        _row(
          _txt(
            'จุดเตือนสั่งซื้อ (Par)',
            fmtQ(_ing.par),
            (v) => _ing = _ing.copyWith(par: double.tryParse(v) ?? 0),
            numKey: true,
          ),
          sups.isNotEmpty
              ? _dd(
                  'แหล่งซื้อหลัก',
                  sups.any((x) => x.id == _ing.supplierId)
                      ? _ing.supplierId
                      : sups.first.id,
                  supMap,
                  (v) => _ing = _ing.copyWith(supplierId: v),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSupplierFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _row(
        _txt(
          'ชื่อแหล่งซื้อ *',
          _sup.name,
          (v) => _sup = _sup.copyWith(name: v),
          placeholder: 'เช่น ตลาดสดเทศบาล / แม็คโคร',
        ),
        _txt(
          'เบอร์โทรศัพท์',
          _sup.phone,
          (v) => _sup = _sup.copyWith(phone: v),
          placeholder: 'เช่น 081-234-5678',
        ),
      ),
      _txt(
        'หมายเหตุ / รายการที่ซื้อประจำ',
        _sup.note,
        (v) => _sup = _sup.copyWith(note: v),
        lines: 2,
        placeholder: 'เช่น ส่งทุกเช้า 08:00 น. เนื้อหมูและผักสด',
      ),
    ],
  );
}
