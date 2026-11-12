import 'package:app/core/di/injection.dart';
import 'package:app/core/printer/printer_hub_modal.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/setup/presentation/widgets/setup_nav_sidebar.dart';
import 'package:flutter/material.dart';

export 'package:app/core/printer/printer_hub_modal.dart';

/// Compact icon-only top header button showing live thermal printer status
/// (via color + status indicator dot) and opening [PrinterHubModal] when
/// tapped.
class PrinterStatusButton extends StatelessWidget {
  const new({super.key, this.compact = false});

  final bool compact;

  ShopConfig _resolveShop() => sl.isRegistered<PosRepository>()
      ? sl<PosRepository>().state.shop
      : const ShopConfig();

  @override
  Widget build(BuildContext context) {
    final hub = PrinterHub.instance;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final t = context.tokens;
        final ready = hub.isReadyToPrint;
        final busy =
            hub.status == PrinterConnStatus.connecting ||
            hub.status == PrinterConnStatus.printing;
        final hasErr = hub.status == PrinterConnStatus.error;
        final (bg, fg, borderCol, dotCol) = hasErr
            ? (t.dangerSoft, t.dangerInk, t.danger, t.danger)
            : busy
            ? (t.primarySoft, t.primaryInk, t.primary, t.primary)
            : ready
            ? (t.successSoft, t.successInk, t.success, t.success)
            : (t.surface, t.muted, t.line, t.muted);

        return Padding(
          padding: const EdgeInsets.only(right: AppDimensions.space2),
          child: Semantics(
            button: true,
            label: 'ตั้งค่าเครื่องพิมพ์ใบเสร็จ · ${hub.statusLabel}',
            child: Tooltip(
              message: 'ตั้งค่าเครื่องพิมพ์ใบเสร็จ (${hub.statusLabel})',
              child: Material(
                key: const ValueKey('printer-status-btn'),
                color: bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  side: BorderSide(
                    color: borderCol,
                    width: AppDimensions.borderThick,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  onTap: () =>
                      showPrinterHubModal(context, shop: _resolveShop()),
                  child: SizedBox(
                    width: AppDimensions.tap,
                    height: AppDimensions.tap,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AppIcon('printer', color: fg),
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            key: ValueKey(
                              'printer-status-dot-'
                              '${ready ? "connected" : "disconnected"}',
                            ),
                            width: AppDimensions.statusDotMd,
                            height: AppDimensions.statusDotMd,
                            decoration: BoxDecoration(
                              color: dotCol,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: t.surface,
                                width: AppDimensions.borderBold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full `/setup` panel for the `'printer'` tab (`เครื่องพิมพ์ใบเสร็จ`).
class SetupPrinterPanel extends StatelessWidget {
  const new({required this.shop, super.key});

  final ShopConfig shop;

  Future<void> _testPrint(BuildContext context, PrinterHub hub) async {
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
      builder: (context, _) => SetupCard(
        key: const ValueKey('setup-printer-panel'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'เครื่องพิมพ์ใบเสร็จ (MP80C1 / 80 มม.)',
              desc:
                  'เชื่อมต่อผ่าน Bluetooth BLE, สายตรง USB หรือ Wi-Fi '
                  'พร้อมทดสอบพิมพ์ภาษาไทยและ QR พร้อมเพย์',
              actions: [
                Btn(
                  key: const ValueKey('printer-test-print-btn'),
                  kind: BtnKind.primary,
                  icon: 'printer',
                  loading: hub.status == PrinterConnStatus.printing,
                  label: 'พิมพ์ใบเสร็จทดสอบ (Test Print)',
                  onPressed: () => _testPrint(context, hub),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space4),
            PrinterHubBody(shop: shop),
          ],
        ),
      ),
    );
  }
}
