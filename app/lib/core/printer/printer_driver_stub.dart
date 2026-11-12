import 'dart:typed_data';

import 'package:app/core/printer/printer_driver.dart';
import 'package:app/core/printer/printer_models.dart';

/// Creates the non-web (VM/test) stub [PrinterPlatformDriver].
PrinterPlatformDriver createPrinterPlatformDriver() =>
    StubPrinterPlatformDriver.instance;

/// In-memory [PrinterPlatformDriver] for Flutter unit and widget tests.
class StubPrinterPlatformDriver implements PrinterPlatformDriver {
  new({
    this.bleSupported = true,
    this.usbSupported = true,
    this.simulatedBleName = 'MP80C1-BLE (Test)',
    this.simulatedUsbName = 'MP80C1-USB (Test)',
    this.onSendBytes,
  });

  static StubPrinterPlatformDriver instance = StubPrinterPlatformDriver();

  bool bleSupported;
  bool usbSupported;
  String simulatedBleName;
  String simulatedUsbName;
  Future<void> Function(Uint8List data, PrinterSettings settings)? onSendBytes;

  bool _connected = false;
  String? _connectedName;
  Uint8List? lastSentBytes;
  PrinterSettings? lastUsedSettings;
  String? lastHtmlTitle;
  Uint8List? lastHtmlPngBytes;
  final List<Uint8List> sentJobs = <Uint8List>[];

  List<DiscoveredNetworkPrinter> simulatedNetworkPrinters =
      const <DiscoveredNetworkPrinter>[
        DiscoveredNetworkPrinter(
          host: '127.0.0.1',
          port: 9100,
          label: 'Local Print Gateway (127.0.0.1:9100)',
        ),
        DiscoveredNetworkPrinter(
          host: '192.168.1.100',
          port: 9100,
          label: 'MP80C1 LAN Printer (192.168.1.100:9100)',
        ),
      ];

  void reset() {
    _connected = false;
    _connectedName = lastHtmlTitle = null;
    lastSentBytes = lastHtmlPngBytes = null;
    lastUsedSettings = null;
    sentJobs.clear();
  }

  @override
  bool get isBleSupported => bleSupported;
  @override
  bool get isUsbSupported => usbSupported;
  @override
  bool get isConnected => _connected;
  @override
  String? get connectedName => _connectedName;

  @override
  Future<String> connectBle() async {
    _connected = true;
    return _connectedName = simulatedBleName;
  }

  @override
  Future<String> connectUsb() async {
    _connected = true;
    return _connectedName = simulatedUsbName;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _connectedName = null;
  }

  @override
  Future<void> sendBytes(
    Uint8List data, {
    required PrinterSettings settings,
  }) async {
    lastSentBytes = data;
    lastUsedSettings = settings;
    sentJobs.add(data);
    await onSendBytes?.call(data, settings);
  }

  @override
  Future<List<DiscoveredNetworkPrinter>> scanNetworkPrinters(
    String subnetPrefix,
  ) async => simulatedNetworkPrinters;

  @override
  Future<void> printHtmlReceipt(
    String title,
    Uint8List pngBytes,
    PaperWidth width,
  ) async {
    lastHtmlTitle = title;
    lastHtmlPngBytes = pngBytes;
  }
}
