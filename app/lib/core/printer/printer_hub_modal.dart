import 'package:app/core/printer/printer_hub.dart';
import 'package:app/core/printer/printer_hub_sections.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';

export 'package:app/core/printer/printer_hub.dart';
export 'package:app/core/printer/printer_hub_sections.dart';

/// Opens the Printer Hub dialog and returns `true` if the printer is ready
/// when the dialog closes.
Future<bool?> showPrinterHubModal(BuildContext context, {ShopConfig? shop}) =>
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppDimensions.space4),
        child: PrinterHubModal(
          shop: shop ?? const ShopConfig(),
          onClose: () =>
              Navigator.of(dialogCtx).pop(PrinterHub.instance.isReadyToPrint),
        ),
      ),
    );

/// Prints [bill] through [PrinterHub.instance], prompting the user with
/// [showPrinterHubModal] first if no transport is connected yet.
Future<void> printBillWithHub(
  BuildContext context, {
  required ShopConfig shop,
  required BillRecord bill,
  bool isCopy = false,
  String? replacesNo,
}) async {
  final hub = PrinterHub.instance;
  if (!hub.isReadyToPrint) {
    await showPrinterHubModal(context, shop: shop);
    if (!context.mounted || !hub.isReadyToPrint) return;
  }
  final ok = await hub.printBill(
    shop,
    bill,
    isCopy: isCopy,
    replacesNo: replacesNo,
  );
  if (!context.mounted) return;
  final doneMsg = bill.isSlipPreview
      ? 'พิมพ์ใบแจ้งยอดเรียบร้อย'
      : 'พิมพ์ใบเสร็จเรียบร้อย';
  showAppToast(
    context,
    ok
        ? doneMsg
        : (hub.errorMessage ?? 'พิมพ์ไม่สำเร็จ กรุณาตรวจสอบเครื่องพิมพ์'),
  );
}

/// Prints [summary] (`ใบสรุปยอดโต๊ะ`) through [PrinterHub.instance], prompting
/// with [showPrinterHubModal] first if no transport is connected yet.
Future<void> printTableSummaryWithHub(
  BuildContext context, {
  required ShopConfig shop,
  required TableSummarySlip summary,
}) async {
  final hub = PrinterHub.instance;
  if (!hub.isReadyToPrint) {
    await showPrinterHubModal(context, shop: shop);
    if (!context.mounted || !hub.isReadyToPrint) return;
  }
  final ok = await hub.printTableSummary(shop, summary);
  if (!context.mounted) return;
  showAppToast(
    context,
    ok
        ? 'พิมพ์ใบสรุปยอดโต๊ะเรียบร้อย'
        : (hub.errorMessage ?? 'พิมพ์ไม่สำเร็จ กรุณาตรวจสอบเครื่องพิมพ์'),
  );
}

/// Reusable Printer Hub configuration body used in both [PrinterHubModal] and
/// the `/setup` printer panel.
class PrinterHubBody extends StatelessWidget {
  const new({required this.shop, super.key});

  final ShopConfig shop;

  Future<void> _connectBle(BuildContext context, PrinterHub hub) async {
    final ok = await hub.connectBle();
    if (!context.mounted) return;
    if (ok) {
      showAppToast(context, hub.statusLabel);
    }
  }

  Future<void> _connectUsb(BuildContext context, PrinterHub hub) async {
    final ok = await hub.connectUsb();
    if (!context.mounted) return;
    if (ok) {
      showAppToast(context, hub.statusLabel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = PrinterHub.instance;
    final t = context.tokens;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final s = hub.settings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrinterStatusBanner(
              hub: hub,
              onConnectBle: () => _connectBle(context, hub),
              onConnectUsb: () => _connectUsb(context, hub),
            ),
            const SizedBox(height: AppDimensions.space3),
            ResponsiveFormRow(
              left: Field(
                label: 'การเชื่อมต่อ',
                child: Seg<PrinterTransport>(
                  key: const ValueKey('printer-transport-seg'),
                  expanded: true,
                  value: s.transport,
                  items: const [
                    SegItem(
                      value: PrinterTransport.ble,
                      icon: 'bluetooth',
                      tooltip: 'Bluetooth (BLE)',
                    ),
                    SegItem(
                      value: PrinterTransport.usb,
                      icon: 'usb',
                      tooltip: 'สายตรง (USB)',
                    ),
                    SegItem(
                      value: PrinterTransport.network,
                      icon: 'wifi',
                      tooltip: 'ผ่านเน็ต (Wi-Fi / IP)',
                    ),
                  ],
                  onChanged: (next) =>
                      hub.updateSettings(s.copyWith(transport: next)),
                ),
              ),
              right: Field(
                label: 'หน้ากว้างกระดาษ',
                child: Seg<PaperWidth>(
                  key: const ValueKey('printer-paper-width-seg'),
                  expanded: true,
                  value: s.paperWidth,
                  items: [
                    for (final pw in PaperWidth.values)
                      SegItem(value: pw, label: '${pw.mm} มม.'),
                  ],
                  onChanged: (pw) =>
                      hub.updateSettings(s.copyWith(paperWidth: pw)),
                ),
              ),
            ),
            PrinterTransportSection(hub: hub),
            const SizedBox(height: AppDimensions.space3),
            ShopLogoPickerField(
              compact: true,
              logoDataUrl: s.effectiveLogoDataUrl(shop),
              onChanged: (url) =>
                  hub.updateSettings(s.copyWith(customLogoDataUrl: url)),
              printLogo: s.printLogo,
              onPrintLogoChanged: (v) =>
                  hub.updateSettings(s.copyWith(printLogo: v)),
            ),
            const SizedBox(height: AppDimensions.space2_5),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space3,
                vertical: AppDimensions.space2,
              ),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: t.line),
              ),
              child: AppSwitch(
                key: const ValueKey('printer-auto-print-switch'),
                value: s.autoPrintOnSettle,
                label: 'พิมพ์ใบเสร็จอัตโนมัติหลังรับชำระเงิน',
                onChanged: (v) =>
                    hub.updateSettings(s.copyWith(autoPrintOnSettle: v)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Modal dialog wrapping [PrinterHubBody] with Test Print and Close actions.
class PrinterHubModal extends StatelessWidget {
  const new({required this.shop, required this.onClose, super.key});

  final ShopConfig shop;
  final VoidCallback onClose;

  Future<void> _runTestPrint(BuildContext context, PrinterHub hub) async {
    final ok = await hub.printTestSlip(shop);
    if (!context.mounted) return;
    showAppToast(
      context,
      ok
          ? 'พิมพ์ใบเสร็จทดสอบเรียบร้อย'
          : (hub.errorMessage ??
                'พิมพ์ทดสอบไม่สำเร็จ กรุณาเชื่อมต่อเครื่องพิมพ์'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hub = PrinterHub.instance;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final busy =
            hub.status == PrinterConnStatus.connecting ||
            hub.status == PrinterConnStatus.printing;
        return Modal(
          key: const ValueKey('printer-hub-modal'),
          title: 'เครื่องพิมพ์ใบเสร็จ',
          onClose: onClose,
          footer: [
            Btn(
              key: const ValueKey('printer-test-print-btn'),
              icon: 'printer',
              loading: hub.status == PrinterConnStatus.printing,
              disabled: busy,
              label: 'พิมพ์ทดสอบ',
              onPressed: () => _runTestPrint(context, hub),
            ),
            Btn(
              key: const ValueKey('printer-hub-close-btn'),
              kind: BtnKind.primary,
              icon: 'check',
              label: 'เสร็จสิ้น',
              onPressed: onClose,
            ),
          ],
          child: PrinterHubBody(shop: shop),
        );
      },
    );
  }
}
