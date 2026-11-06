import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/formatters.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:app/features/setup/presentation/widgets/setup_finance_catalog_panels.dart';
import 'package:flutter/material.dart';

export 'package:app/features/setup/presentation/widgets/setup_finance_catalog_panels.dart'
    show SetupDeleteCallback, SetupEditCallback;

/// Interactive CRUD catalog table panel for `/setup`.
class SetupCatalogPanel extends StatelessWidget {
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
    int flex = 2,
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
      'packages' => CrudSectionShell<PackageItem>(
        title: 'แพ็กเกจบุฟเฟต์',
        desc: 'ราคาผู้ใหญ่ ราคาเด็ก และเวลาจำกัดต่อโต๊ะ',
        addButtonKey: const ValueKey('setup-add-packages-btn'),
        addLabel: 'เพิ่มแพ็กเกจ',
        headerPills: [
          Pill(
            tone: PillTone.green,
            child: Text(
              'เปิดขาย ${s.packages.where((p) => p.active).length}'
              '/${s.packages.length}',
            ),
          ),
        ],
        rows: state.filteredPackages,
        itemNameOf: (p) => p.name,
        onAdd: () => onOpenEditor('packages', null),
        onEdit: (p) => onOpenEditor('packages', p),
        onDelete: (p) => onRequestDelete('packages', p.id, p.name),
        columns: [
          _col('name', 'ชื่อแพ็กเกจ', (p) => p.name, flex: 3),
          _col('adult', 'ผู้ใหญ่', (p) => baht(p.adultPrice)),
          _col('child', 'เด็ก', (p) => baht(p.childPrice)),
          _col(
            'time',
            'เวลาจำกัด',
            (p) => p.timeLimit > 0 ? '${p.timeLimit} นาที' : 'ไม่จำกัด',
          ),
          DataTableCol(
            key: 'active',
            label: 'สถานะขาย',
            flex: 3,
            cellBuilder: (_, p) => _activeSwitchCell(
              active: p.active,
              onText: 'เปิดขาย',
              offText: 'ปิด',
              semanticLabel: 'เปิดขาย ${p.name}',
              onChanged: (on) => cubit.togglePackageActive(p, active: on),
            ),
          ),
        ],
      ),
      'addons' => CrudSectionShell<AddonItem>(
        title: 'สินค้าขายเสริม · เครื่องดื่ม',
        desc: 'คิดเงินเพิ่มนอกบุฟเฟต์ และตัดสต็อกเมื่อส่งออเดอร์/รับเงิน',
        addButtonKey: const ValueKey('setup-add-addons-btn'),
        addLabel: 'เพิ่มสินค้าเสริม',
        headerPills: [
          Pill(
            tone: PillTone.green,
            child: Text(
              'เปิดขาย ${s.addons.where((a) => a.active).length}'
              '/${s.addons.length}',
            ),
          ),
        ],
        rows: state.filteredAddons,
        itemNameOf: (a) => a.name,
        onAdd: () => onOpenEditor('addons', null),
        onEdit: (a) => onOpenEditor('addons', a),
        onDelete: (a) => onRequestDelete('addons', a.id, a.name),
        columns: [
          _col('name', 'ชื่อสินค้า', (a) => a.name, flex: 3),
          _col('cat', 'หมวด', (a) => a.category),
          _col('price', 'ราคาขาย', (a) => baht(a.price)),
          _col('cost', 'ต้นทุน/หน่วย', (a) => '฿${fmtQ(a.cost)}'),
          _col('stock', 'คงเหลือ', (a) => fmt(a.stock)),
          DataTableCol(
            key: 'active',
            label: 'สถานะขาย',
            flex: 3,
            cellBuilder: (_, a) => _activeSwitchCell(
              active: a.active,
              onText: 'เปิดขาย',
              offText: 'ปิด',
              semanticLabel: 'เปิดขาย ${a.name}',
              onChanged: (on) => cubit.toggleAddonActive(a, active: on),
            ),
          ),
        ],
      ),
      'ingredients' => CrudSectionShell<IngredientItem>(
        title: 'วัตถุดิบและของใช้สิ้นเปลือง',
        desc: 'สำหรับรับของตอนเช้า และนับของเหลือปิดวันเพื่อคำนวณต้นทุนจริง',
        addButtonKey: const ValueKey('setup-add-ingredients-btn'),
        addLabel: 'เพิ่มวัตถุดิบ',
        headerPills: [
          Pill(child: Text('ทั้งหมด ${s.ingredients.length} รายการ')),
        ],
        rows: state.filteredIngredients,
        itemNameOf: (i) => i.name,
        onAdd: () => onOpenEditor('ingredients', null),
        onEdit: (i) => onOpenEditor('ingredients', i),
        onDelete: (i) => onRequestDelete('ingredients', i.id, i.name),
        columns: [
          _col('name', 'วัตถุดิบ', (i) => i.name, flex: 3),
          _col('unit', 'หน่วยนับ', (i) => i.unit, flex: 1),
          _col(
            'loc',
            'สถานที่จัดเก็บ',
            (i) => kLocations[i.location] ?? i.location,
          ),
          _col(
            'freq',
            'รอบการตรวจนับ',
            (i) => kCountFreqs[i.countFreq] ?? i.countFreq,
          ),
          _col('cost', 'ต้นทุนล่าสุด', (i) => '฿${fmtQ(i.lastCost)}'),
          _col('par', 'เกณฑ์คงเหลือขั้นต่ำ', (i) => '${fmtQ(i.par)} ${i.unit}'),
        ],
      ),
      'suppliers' => CrudSectionShell<SupplierItem>(
        title: 'แหล่งซื้อของ',
        desc: 'ตลาดสด ร้านส่ง หรือคู่ค้าที่ใช้บันทึกใบรับของตอนเช้า',
        addButtonKey: const ValueKey('setup-add-suppliers-btn'),
        addLabel: 'เพิ่มแหล่งซื้อ',
        headerPills: [Pill(child: Text('ทั้งหมด ${s.suppliers.length} แหล่ง'))],
        rows: state.filteredSuppliers,
        itemNameOf: (x) => x.name,
        onAdd: () => onOpenEditor('suppliers', null),
        onEdit: (x) => onOpenEditor('suppliers', x),
        onDelete: (x) => onRequestDelete('suppliers', x.id, x.name),
        columns: [
          _col('name', 'ชื่อแหล่งซื้อ', (x) => x.name, flex: 3),
          _col('phone', 'เบอร์โทร', (x) => x.phone.isEmpty ? '-' : x.phone),
          _col(
            'note',
            'หมายเหตุ',
            (x) => x.note.isEmpty ? '-' : x.note,
            flex: 4,
          ),
        ],
      ),
      'tables' => CrudSectionShell<DiningTable>(
        title: 'โต๊ะในร้าน',
        desc: 'ผังโต๊ะและโซนที่แสดงในหน้า โต๊ะ',
        addButtonKey: const ValueKey('setup-add-tables-btn'),
        addLabel: 'เพิ่มโต๊ะ',
        summaryBanner: StatsGroup(
          children: [
            Stat(
              label: 'จำนวนโต๊ะทั้งหมด',
              value: '${s.tables.length} โต๊ะ',
              sub: 'พร้อมเปิดรับลูกค้า',
            ),
            Stat(
              label: 'ความจุรวมทั้งร้าน',
              value: '${s.tables.fold<int>(0, (a, t) => a + t.seats)} ที่นั่ง',
              sub: 'รองรับลูกค้าพร้อมกัน',
            ),
            Stat(
              label: 'โซนที่นั่ง',
              value: '${s.tables.map((t) => t.zone).toSet().length} โซน',
              sub: s.tables.map((t) => t.zone).toSet().join(' · '),
            ),
          ],
        ),
        rows: state.filteredTables,
        itemNameOf: (t) => t.name,
        onAdd: () => onOpenEditor('tables', null),
        onEdit: (t) => onOpenEditor('tables', t),
        onDelete: (t) => onRequestDelete('tables', t.id, t.name),
        columns: [
          _col('name', 'ชื่อโต๊ะ', (t) => t.name),
          _col('seats', 'จำนวนที่นั่ง', (t) => '${t.seats} ที่นั่ง'),
          _col('zone', 'โซน', (t) => t.zone, flex: 3),
        ],
      ),
      _ => SetupFinanceCatalogPanel(
        state: state,
        cubit: cubit,
        staffRole: staffRole,
        onOpenEditor: onOpenEditor,
        onRequestDelete: onRequestDelete,
      ),
    };
  }
}
