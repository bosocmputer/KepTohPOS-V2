import 'package:app/core/printer/printer_hub.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Top status banner inside the Printer Hub showing live connection state,
/// active device/endpoint, error alert (if any), and primary connect/disconnect
/// action button on the same row.
class PrinterStatusBanner extends StatelessWidget {
  const new({
    required this.hub,
    required this.onConnectBle,
    required this.onConnectUsb,
    super.key,
  });

  final PrinterHub hub;
  final VoidCallback onConnectBle;
  final VoidCallback onConnectUsb;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final s = hub.settings;
    final ready = hub.isReadyToPrint;
    final busy =
        hub.status == PrinterConnStatus.connecting ||
        hub.status == PrinterConnStatus.printing;
    final isHw = s.transport != PrinterTransport.network;
    final hasHwConn =
        isHw &&
        (hub.status == PrinterConnStatus.connected ||
            hub.connectedDeviceName != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('printer-status-banner'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space3_5,
            vertical: AppDimensions.space3,
          ),
          decoration: BoxDecoration(
            color: ready ? t.successSoft : t.surface2,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: ready ? t.success : t.line),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ready ? t.surface : t.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon(
                    ready ? 'check' : 'printer',
                    color: ready ? t.successInk : t.muted,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.space2_5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready ? hub.statusLabel : 'ยังไม่เชื่อมต่อเครื่องพิมพ์',
                      style: tt.bodyMedium?.copyWith(
                        color: ready ? t.successInk : t.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${s.transport.label} · กระดาษ ${s.paperWidth.mm} มม.',
                      style: tt.labelSmall?.copyWith(
                        color: ready ? t.successInk : t.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasHwConn)
                Btn(
                  key: const ValueKey('printer-disconnect-btn'),
                  size: BtnSize.sm,
                  kind: BtnKind.danger,
                  label: 'ตัดการเชื่อมต่อ',
                  disabled: busy,
                  onPressed: hub.disconnect,
                )
              else if (s.transport == PrinterTransport.ble)
                Btn(
                  key: const ValueKey('printer-connect-ble-btn'),
                  size: BtnSize.sm,
                  kind: BtnKind.primary,
                  icon: 'search',
                  loading: hub.status == PrinterConnStatus.connecting,
                  disabled: busy,
                  label: 'ค้นหาเครื่องพิมพ์',
                  onPressed: onConnectBle,
                )
              else if (s.transport == PrinterTransport.usb)
                Btn(
                  key: const ValueKey('printer-connect-usb-btn'),
                  size: BtnSize.sm,
                  kind: BtnKind.primary,
                  icon: 'search',
                  loading: hub.status == PrinterConnStatus.connecting,
                  disabled: busy,
                  label: 'เชื่อมต่อสาย USB',
                  onPressed: onConnectUsb,
                ),
            ],
          ),
        ),
        if ((hub.errorMessage ?? '').isNotEmpty) ...[
          const SizedBox(height: AppDimensions.space2),
          Container(
            key: const ValueKey('printer-error-banner'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space3,
              vertical: AppDimensions.space2,
            ),
            decoration: BoxDecoration(
              color: t.dangerSoft,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: t.danger),
            ),
            child: Row(
              children: [
                AppIcon('alert', size: 15, color: t.dangerInk),
                const SizedBox(width: AppDimensions.space2),
                Expanded(
                  child: Text(
                    hub.errorMessage!,
                    style: tt.labelSmall?.copyWith(
                      color: t.dangerInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Transport-specific connection controls for BLE, USB/Serial, or IP Network.
class PrinterTransportSection extends StatelessWidget {
  const new({required this.hub, super.key});

  final PrinterHub hub;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final s = hub.settings;

    return switch (s.transport) {
      PrinterTransport.ble => Padding(
        key: const ValueKey('printer-ios-ble-guide'),
        padding: const EdgeInsets.only(top: AppDimensions.space1_5),
        child: Row(
          children: [
            AppIcon('alert', size: 14, color: t.muted),
            const SizedBox(width: AppDimensions.space1_5),
            Expanded(
              child: Text(
                'เชื่อมต่อจากปุ่มด้านบนโดยตรง '
                'ไม่ต้องจับคู่ในหน้าตั้งค่าบลูทูธของเครื่อง '
                '(iPad แนะนำแอป Bluefy)',
                style: tt.labelSmall?.copyWith(color: t.muted),
              ),
            ),
          ],
        ),
      ),
      PrinterTransport.usb => Padding(
        padding: const EdgeInsets.only(top: AppDimensions.space1_5),
        child: Text(
          'เสียบสาย USB เข้ากับเครื่องพิมพ์โดยตรง รองรับโหมด USB Printing / Serial โดยไม่ต้องลงไดรเวอร์',
          style: tt.labelSmall?.copyWith(color: t.muted),
        ),
      ),
      PrinterTransport.network => Container(
        margin: const EdgeInsets.only(top: AppDimensions.space2_5),
        padding: const EdgeInsets.all(AppDimensions.space3),
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: t.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveFormRow(
              left: Field(
                label: 'IP Address',
                child: AppTextInput(
                  key: const ValueKey('printer-ip-input'),
                  value: s.networkHost,
                  placeholder: '192.168.1.100',
                  onChanged: (v) =>
                      hub.updateSettings(s.copyWith(networkHost: v.trim())),
                ),
              ),
              right: Field(
                label: 'Port',
                child: AppTextInput(
                  key: const ValueKey('printer-port-input'),
                  value: '${s.networkPort}',
                  placeholder: '9100',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => hub.updateSettings(
                    s.copyWith(networkPort: int.tryParse(v) ?? 9100),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Btn(
                  key: const ValueKey('printer-scan-lan-btn'),
                  size: BtnSize.sm,
                  icon: 'search',
                  loading: hub.isScanningNetwork,
                  disabled: hub.isScanningNetwork,
                  label: 'สแกนวงแลน',
                  onPressed: hub.scanNetwork,
                ),
                const SizedBox(width: AppDimensions.space3),
                Expanded(
                  child: AppSwitch(
                    key: const ValueKey('printer-system-fallback-switch'),
                    value: s.useSystemPrintFallback,
                    label: 'ใช้หน้าต่างพิมพ์ของระบบ (AirPrint)',
                    onChanged: (v) => hub.updateSettings(
                      s.copyWith(useSystemPrintFallback: v),
                    ),
                  ),
                ),
              ],
            ),
            if (hub.discoveredPrinters.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.space2),
              Wrap(
                spacing: AppDimensions.space1_5,
                runSpacing: AppDimensions.space1_5,
                children: [
                  for (final p in hub.discoveredPrinters)
                    Btn(
                      key: ValueKey('printer-discovered-${p.address}'),
                      size: BtnSize.sm,
                      kind: s.networkHost == p.host && s.networkPort == p.port
                          ? BtnKind.primary
                          : BtnKind.normal,
                      label: '${p.label} (${p.address})',
                      onPressed: () => hub.updateSettings(
                        s.copyWith(networkHost: p.host, networkPort: p.port),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    };
  }
}
