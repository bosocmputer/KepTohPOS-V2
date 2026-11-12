import 'dart:typed_data';

import 'package:app/core/printer/printer_status_button.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePrinterDriver implements PrinterPlatformDriver {
  bool bleSupported = true;
  bool usbSupported = true;
  bool connected = false;
  String? activeName;
  int connectBleCalls = 0;
  int connectUsbCalls = 0;
  int htmlPrintCalls = 0;
  final List<Uint8List> sentJobs = <Uint8List>[];

  @override
  bool get isBleSupported => bleSupported;

  @override
  bool get isUsbSupported => usbSupported;

  @override
  bool get isConnected => connected;

  @override
  String? get connectedName => activeName;

  @override
  Future<String> connectBle() async {
    connectBleCalls++;
    connected = true;
    return activeName = 'MP80C1-BLE';
  }

  @override
  Future<String> connectUsb() async {
    connectUsbCalls++;
    connected = true;
    return activeName = 'MP80C1-USB';
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    activeName = null;
  }

  @override
  Future<void> sendBytes(
    Uint8List data, {
    required PrinterSettings settings,
  }) async {
    sentJobs.add(data);
  }

  @override
  Future<List<DiscoveredNetworkPrinter>> scanNetworkPrinters(
    String subnetPrefix,
  ) async => <DiscoveredNetworkPrinter>[
    DiscoveredNetworkPrinter(
      host: '$subnetPrefix.100',
      port: 9100,
      label: 'MP80C1 Print Gateway',
    ),
  ];

  @override
  Future<void> printHtmlReceipt(
    String title,
    Uint8List pngBytes,
    PaperWidth width,
  ) async {
    htmlPrintCalls++;
  }
}

const ShopConfig _kShop = ShopConfig(
  name: 'ร้านหมูกระทะริมน้ำ',
  branch: 'สาขาลาดพร้าว',
  phone: '081-234-5678',
  promptpay: '0812345678',
  taxId: '0105560001234',
);

final BillRecord _kBill = BillRecord(
  id: 'b-101',
  no: 'INV691112-0001',
  date: '2026-11-12',
  at: '2026-11-12T12:00:00Z',
  tableId: 't1',
  tableName: 'A1',
  staffId: 'st1',
  staffName: 'น้องเมย์',
  packageId: 'p1',
  heads: HeadsCount(a: 2),
  lines: const <OrderLineItem>[
    OrderLineItem(
      type: 'buffet',
      id: 'p1',
      name: 'บุฟเฟต์หมู',
      price: 299,
      qty: 2,
    ),
  ],
  subtotal: 598,
  service: 0,
  vat: 39,
  rounding: 0,
  total: 598,
  methodId: 'pm-qr',
  methodName: 'พร้อมเพย์ QR',
  methodType: 'qr',
  received: 598,
  change: 0,
  isTaxInvoice: true,
);

void main() {
  test('rgbaToMonochromeRaster and encodeGsV0Chunks encode 80mm & 58mm', () {
    const w80 = 576;
    const h = 40;
    final rgba = Uint8List(w80 * h * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba[i] = 255;
      rgba[i + 1] = 255;
      rgba[i + 2] = 255;
      rgba[i + 3] = 255;
    }
    for (var x = 0; x < w80; x++) {
      final p = (10 * w80 + x) * 4;
      rgba[p] = 0;
      rgba[p + 1] = 0;
      rgba[p + 2] = 0;
      rgba[p + 3] = 255;
    }

    final mono = rgbaToMonochromeRaster(rgba, w80, h);
    expect(mono.bytesPerRow, 72);
    expect(mono.heightRows, 27);
    expect(mono.bytes[10 * 72], 0xFF);

    final esc = encodeGsV0Chunks(mono.bytes, mono.widthDots, mono.heightRows);
    expect(esc.sublist(0, 6), <int>[0x1B, 0x40, 0x1D, 0x76, 0x30, 0x00]);
    expect(esc[6], 72);
    expect(esc[7], 0);
    expect(esc.sublist(esc.length - 7), <int>[
      0x1B,
      0x64,
      0x04,
      0x1D,
      0x56,
      0x42,
      0x00,
    ]);

    // Verify Atkinson dithering produces halftone dots for orange (#F97316)
    final orangeRgba = Uint8List(64 * 16 * 4);
    for (var i = 0; i < orangeRgba.length; i += 4) {
      orangeRgba[i] = 0xF9;
      orangeRgba[i + 1] = 0x73;
      orangeRgba[i + 2] = 0x16;
      orangeRgba[i + 3] = 0xFF;
    }
    final dithered = rgbaToMonochromeRaster(orangeRgba, 64, 16);
    final nonZero = dithered.bytes.where((b) => b != 0 && b != 0xFF).length;
    expect(nonZero, greaterThan(0));
  });

  test('decodeLogoDataUrl and effectiveLogoDataUrl resolve custom logo', () {
    const sampleUrl =
        'data:image/png;base64,'
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4'
        'nGNgYGAAAAAEAAH2FzhVAAAAAElFTkSuQmCC';
    final decoded = decodeLogoDataUrl(sampleUrl);
    expect(decoded, isNotNull);
    expect(decoded!.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
    expect(decodeLogoDataUrl(''), isNull);
    expect(decodeLogoDataUrl('invalid-base64-%%%'), isNull);

    const settings = PrinterSettings(customLogoDataUrl: sampleUrl);
    expect(settings.effectiveLogoDataUrl(_kShop), sampleUrl);
  });

  test(
    'Thai raster painter renders test slip, bill, and table summary',
    () async {
      final testBytes = await renderTestPrintEscPos(
        shop: _kShop,
        paperWidth: PaperWidth.mm80,
        connectionLabel: 'MP80C1-BLE',
      );
      expect(testBytes.length, greaterThan(1000));
      expect(testBytes.sublist(0, 2), <int>[0x1B, 0x40]);

      final billBytes = await renderBillEscPos(
        shop: _kShop,
        bill: _kBill,
        paperWidth: PaperWidth.mm58,
        isCopy: true,
      );
      expect(billBytes.length, greaterThan(1000));

      final pngBytes = await renderReceiptPngBytes(
        shop: _kShop,
        bill: _kBill,
        paperWidth: PaperWidth.mm80,
      );
      expect(pngBytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);

      final summary = TableSummarySlip(
        tableId: 't1',
        tableName: 'A1',
        openedAt: '2026-11-12T11:00:00Z',
        eatUntil: '2026-11-12T12:30:00Z',
        timeLimitMin: 90,
        timer: const TableTimerStatus(
          mins: 60,
          limit: 90,
          late: false,
          text: 'เหลือ 30 นาที',
        ),
        heads: HeadsCount(a: 2),
        bills: <BillRecord>[_kBill],
        mergedLines: _kBill.lines,
        subtotal: 598,
        service: 0,
        vat: 39,
        rounding: 0,
        total: 598,
        voidedCount: 0,
      );
      final sumBytes = await renderTableSummaryEscPos(
        shop: _kShop,
        summary: summary,
        paperWidth: PaperWidth.mm80,
      );
      expect(sumBytes.length, greaterThan(1000));
    },
  );

  testWidgets('PrinterStatusButton opens PrinterHubModal & prints receipt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final driver = _FakePrinterDriver();
    PrinterHub.resetForTest(driver, const PrinterSettings());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(brightness: Brightness.light),
        home: Scaffold(
          body: Column(
            children: [
              const PrinterStatusButton(),
              Builder(
                builder: (ctx) => ElevatedButton(
                  key: const ValueKey('test-print-bill-btn'),
                  onPressed: () =>
                      printBillWithHub(ctx, shop: _kShop, bill: _kBill),
                  child: const Text('Print Bill'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('printer-status-btn')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('printer-status-dot-disconnected')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('printer-status-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('printer-hub-modal')), findsOneWidget);
    expect(find.byKey(const ValueKey('printer-ios-ble-guide')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-shop-logo-btn')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('printer-print-logo-switch')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('pick-shop-logo-btn')),
    );
    await tester.tap(find.byKey(const ValueKey('pick-shop-logo-btn')));
    await tester.pumpAndSettle();
    expect(PrinterHub.instance.settings.customLogoDataUrl, isNotEmpty);

    await tester.tap(find.byKey(const ValueKey('printer-connect-ble-btn')));
    await tester.pumpAndSettle();

    expect(driver.connectBleCalls, 1);
    expect(PrinterHub.instance.isReadyToPrint, isTrue);
    expect(find.textContaining('เชื่อมต่อแล้ว: MP80C1-BLE'), findsWidgets);
    expect(
      find.byKey(const ValueKey('printer-status-dot-connected')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('printer-hub-close-btn')));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final ok = await PrinterHub.instance.printBill(_kShop, _kBill);
      expect(ok, isTrue);
    });
    await tester.pump();

    expect(driver.sentJobs, hasLength(1));
    expect(driver.sentJobs.first.sublist(0, 2), <int>[0x1B, 0x40]);
  });
}
