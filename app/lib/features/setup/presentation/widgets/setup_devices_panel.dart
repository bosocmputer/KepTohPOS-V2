import 'package:app/core/data/supabase/supabase_pos_repository.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/utils/open_url.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/domain/pos_command_exception.dart';
import 'package:app/features/onboarding/data/device_session.dart';
import 'package:app/features/setup/presentation/widgets/setup_device_leave_section.dart';
import 'package:app/features/setup/presentation/widgets/setup_device_rd_code_dialog.dart';
import 'package:app/features/setup/presentation/widgets/setup_device_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The link a new device opens to join the shop. `openExternalBrowser=1`
/// makes LINE open it in the phone's browser, where the pairing is kept.
String deviceLink(String origin, String code) =>
    '$origin/?pair=$code&openExternalBrowser=1';

/// Owner-only list of the shop's devices, with a link to add one more: a
/// second tablet, or a manager's phone for checking reports from home.
class SetupDevicesPanel extends StatefulWidget {
  const new({required this.staffRole, super.key});

  /// Only the owner may take this device out of the shop.
  final String staffRole;

  @override
  State<SetupDevicesPanel> createState() => _SetupDevicesPanelState();
}

class _SetupDevicesPanelState extends State<SetupDevicesPanel> {
  final DeviceSession? _session = sl.isRegistered<DeviceSession>()
      ? sl<DeviceSession>()
      : null;
  late final String? _shopId = switch (sl<PosRepository>()) {
    final SupabasePosRepository r => r.shopId,
    _ => null,
  };
  late Future<List<ShopDevice>> _devices = _load();
  String _name = '';
  String? _link;
  bool _busy = false;
  String _error = '';

  Future<List<ShopDevice>> _load() async {
    final session = _session;
    final shopId = _shopId;
    if (session == null || shopId == null || !session.isOwnerSignedIn) {
      return const <ShopDevice>[];
    }
    return await session.shopDevices(shopId);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await action();
      _devices = _load();
    } on Object {
      _error = 'ทำรายการไม่สำเร็จ กรุณาลองใหม่';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() => _run(() async {
    final code = await _session!.createDeviceCode(_shopId!, _name.trim());
    _link = deviceLink(Uri.base.origin, code);
    _name = '';
  });

  Future<void> _revoke(ShopDevice d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Confirm(
        title: 'ยกเลิก ${d.name}?',
        text: 'เครื่องนี้จะใช้ร้านไม่ได้อีก ถ้าจะใช้ต่อต้องส่งลิงก์ใหม่',
        yesLabel: 'ยกเลิกเครื่อง',
        danger: true,
        yesKey: const ValueKey('device-revoke-confirm-btn'),
        onYes: () => Navigator.pop(context, true),
        onNo: () => Navigator.pop(context, false),
      ),
    );
    if (ok ?? false) await _run(() => _session!.revokeDevice(d.id));
  }

  Future<void> _editRdCode(ShopDevice d) async {
    final saved = await showRdMachineCodeDialog(
      context,
      deviceName: d.name,
      current: d.rdMachineCode,
      onSave: (code) async {
        try {
          await _session!.setRdMachineCode(d.id, code);
        } on Object catch (e) {
          throw switch (sl<PosRepository>()) {
            final SupabasePosRepository r => r.describeError(e),
            _ => const PosCommandException('ทำรายการไม่สำเร็จ'),
          };
        }
      },
    );
    if ((saved ?? false) && mounted) setState(() => _devices = _load());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final session = _session;
    return Column(
      key: const ValueKey('setup-devices-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'เครื่องและลิงก์เข้าร้าน',
          desc:
              'ส่งลิงก์ให้แท็บเล็ตเครื่องใหม่ หรือมือถือผู้จัดการ '
              'เปิดแล้วเข้าร้านนี้ได้ทันที '
              'จากนั้นแต่ละคนเข้าด้วย PIN ของตัวเอง',
        ),
        const SizedBox(height: AppDimensions.space3),
        if (session == null || _shopId == null)
          const Empty(title: 'ใช้ได้เมื่อเชื่อมต่อฐานข้อมูลของร้านจริง')
        else if (!session.isOwnerSignedIn)
          const Empty(title: 'เข้าสู่ระบบบัญชีเจ้าของร้านด้านบนก่อน')
        else ...[
          _createRow(),
          if (_link != null) _linkCard(_link!),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space2),
            Text(_error, style: TextStyle(color: t.dangerInk)),
          ],
          const SizedBox(height: AppDimensions.space3),
          _deviceList(),
        ],
        if (session != null && widget.staffRole == 'owner')
          SetupDeviceLeaveSection(session: session),
      ],
    );
  }

  Widget _createRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Field(
          label: 'ชื่อเครื่อง เช่น แท็บเล็ตหน้าร้าน, มือถือผู้จัดการ',
          child: AppTextInput(
            key: const ValueKey('device-name-input'),
            value: _name,
            onChanged: (v) => setState(() => _name = v),
          ),
        ),
      ),
      const SizedBox(width: AppDimensions.space2),
      Btn(
        key: const ValueKey('device-create-btn'),
        label: 'สร้างลิงก์เข้าร้าน',
        kind: BtnKind.primary,
        disabled: _busy || _name.trim().isEmpty,
        onPressed: _create,
      ),
    ],
  );

  Widget _linkCard(String link) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QrImageView(
            data: link,
            size: 160,
            backgroundColor: AppRawTokens.qrBg,
          ),
          const SizedBox(height: AppDimensions.space2),
          SelectableText(
            link,
            key: const ValueKey('device-link-text'),
            style: tt.bodySmall,
          ),
          Text('ใช้ได้ครั้งเดียว ภายใน 24 ชั่วโมง', style: tt.labelSmall),
          const SizedBox(height: AppDimensions.space2),
          Wrap(
            spacing: AppDimensions.space2,
            children: [
              Btn(
                key: const ValueKey('device-share-line-btn'),
                label: 'ส่งทาง LINE',
                kind: BtnKind.primary,
                onPressed: () => openUrl(
                  'https://line.me/R/share?text='
                  '${Uri.encodeComponent('ลิงก์เข้าร้าน KepToh POS: $link')}',
                ),
              ),
              Btn(
                key: const ValueKey('device-copy-btn'),
                label: 'คัดลอกลิงก์',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (mounted) showAppToast(context, 'คัดลอกลิงก์แล้ว');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deviceList() => FutureBuilder<List<ShopDevice>>(
    future: _devices,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: WalkingOrangeLoader(size: 180, label: 'กำลังโหลดข้อมูล…'),
        );
      }
      if (snapshot.hasError) {
        return const Empty(title: 'โหลดรายชื่อเครื่องไม่ได้');
      }
      return SetupDeviceTable(
        devices: snapshot.data!,
        busy: _busy,
        onEditRd: _editRdCode,
        onRevoke: _revoke,
      );
    },
  );
}
