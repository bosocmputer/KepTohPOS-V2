import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:flutter/material.dart';

/// Rows of the owner's device list: name + status on one line, the RD
/// machine-code status below, and one action group on the right.
class SetupDeviceTable extends StatelessWidget {
  const new({
    required this.devices,
    required this.busy,
    required this.onEditRd,
    required this.onRevoke,
    super.key,
  });

  final List<ShopDevice> devices;
  final bool busy;
  final ValueChanged<ShopDevice> onEditRd;
  final ValueChanged<ShopDevice> onRevoke;

  @override
  Widget build(BuildContext context) {
    final table = PosDataTable<ShopDevice>(
      rows: devices,
      empty: const Empty(
        title: 'ยังไม่มีอุปกรณ์ในร้าน',
        text: 'สร้างลิงก์เข้าร้านด้านบนเพื่อเชื่อมต่อเครื่องใหม่',
      ),
      columns: [
        DataTableCol<ShopDevice>(
          key: 'device',
          label: 'เครื่อง',
          flex: 3,
          cellBuilder: _deviceCell,
        ),
        DataTableCol<ShopDevice>(
          key: 'actions',
          label: 'จัดการ',
          width: 280,
          align: ColAlign.right,
          cellBuilder: _actionsCell,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (_, c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: c.maxWidth < 560 ? 560 : c.maxWidth,
          child: table,
        ),
      ),
    );
  }

  Widget _deviceCell(BuildContext context, ShopDevice d) {
    final tt = Theme.of(context).textTheme;
    final t = context.tokens;
    return Column(
      key: ValueKey('device-row-${d.code}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppDimensions.space1,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppDimensions.space2,
          children: [
            Flexible(
              child: Text(
                '${d.name} (${d.code})',
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(
                  color: t.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Pill(
              label: switch (d) {
                ShopDevice(revoked: true) => 'ยกเลิกแล้ว',
                ShopDevice(isThisDevice: true) => 'เครื่องนี้',
                ShopDevice(paired: true) => 'ใช้งานอยู่',
                _ => 'รอเปิดลิงก์',
              },
              tone: d.revoked
                  ? PillTone.neutral
                  : d.paired
                  ? PillTone.green
                  : PillTone.orange,
            ),
          ],
        ),
        if (!d.revoked) _rdCodeRow(context, d),
      ],
    );
  }

  Widget _actionsCell(BuildContext context, ShopDevice d) {
    if (d.revoked) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppDimensions.space1_5,
      children: [
        Btn(
          key: ValueKey('device-rd-edit-${d.code}'),
          label: 'แก้ไขเลขรหัส',
          size: BtnSize.sm,
          disabled: busy,
          onPressed: () => onEditRd(d),
        ),
        if (!d.isThisDevice)
          Btn(
            key: ValueKey('device-revoke-${d.code}'),
            label: d.paired ? 'ยกเลิกเครื่อง' : 'ยกเลิกลิงก์',
            kind: BtnKind.danger,
            size: BtnSize.sm,
            disabled: busy,
            onPressed: () => onRevoke(d),
          ),
      ],
    );
  }

  Widget _rdCodeRow(BuildContext context, ShopDevice d) {
    final code = d.rdMachineCode;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppDimensions.space2,
      children: [
        Pill(
          label: code == null ? 'ยังไม่ได้ใส่' : 'ใส่แล้ว',
          tone: code == null ? PillTone.neutral : PillTone.green,
        ),
        Flexible(
          child: Text(
            code == null ? 'พิมพ์ได้แค่ใบเสร็จธรรมดา' : 'เลขรหัส $code',
            key: ValueKey('device-rd-code-${d.code}'),
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(color: context.tokens.muted),
          ),
        ),
      ],
    );
  }
}
