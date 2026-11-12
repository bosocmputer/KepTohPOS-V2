import 'package:app/core/printer/printer_driver.dart';
import 'package:app/core/printer/printer_models.dart';
import 'package:app/core/printer/receipt_raster_painter.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/foundation.dart';

export 'package:app/core/printer/esc_pos_raster.dart';
export 'package:app/core/printer/printer_driver.dart';
export 'package:app/core/printer/printer_models.dart';
export 'package:app/core/printer/receipt_raster_painter.dart';
export 'package:app/core/printer/shop_logo_picker.dart';

/// Central thermal printer service managing BLE, USB/Serial, and IP/System
/// print connections, persistent settings, and ESC/POS raster job dispatch.
class PrinterHub extends ChangeNotifier {
  new _(this._driver, this._settings);

  /// Creates an isolated [PrinterHub] instance for unit/widget testing.
  @visibleForTesting
  new forTest(this._driver, [PrinterSettings? initialSettings])
    : _settings = initialSettings ?? const PrinterSettings();

  static PrinterHub _instance = PrinterHub._(
    PrinterPlatformDriver(),
    PrinterSettings.load(),
  );

  /// Global singleton instance.
  static PrinterHub get instance => _instance;

  /// Resets the global singleton for tests.
  @visibleForTesting
  static void resetForTest([
    PrinterPlatformDriver? driver,
    PrinterSettings? initialSettings,
  ]) {
    _instance = PrinterHub.forTest(
      driver ?? PrinterPlatformDriver(),
      initialSettings ?? PrinterSettings.load(),
    );
  }

  final PrinterPlatformDriver _driver;
  PrinterSettings _settings;
  PrinterConnStatus _status = PrinterConnStatus.disconnected;
  String? _connectedDeviceName;
  String? _errorMessage;
  List<DiscoveredNetworkPrinter> _discoveredPrinters = const [];
  bool _isScanningNetwork = false;

  PrinterSettings get settings => _settings;
  PrinterConnStatus get status => _status;
  String? get connectedDeviceName =>
      _connectedDeviceName ?? _driver.connectedName;
  String? get errorMessage => _errorMessage;
  List<DiscoveredNetworkPrinter> get discoveredPrinters => _discoveredPrinters;
  bool get isScanningNetwork => _isScanningNetwork;
  bool get isBleSupported => _driver.isBleSupported;
  bool get isUsbSupported => _driver.isUsbSupported;

  /// Whether the currently selected transport is ready to accept a print job.
  bool get isReadyToPrint => switch (_settings.transport) {
    PrinterTransport.network =>
      _settings.useSystemPrintFallback ||
          _settings.networkHost.trim().isNotEmpty,
    PrinterTransport.ble || PrinterTransport.usb =>
      _status == PrinterConnStatus.connected || _driver.isConnected,
  };

  /// Concise Thai status label for header chips and banners.
  String get statusLabel {
    if (_status == PrinterConnStatus.printing) return 'กำลังพิมพ์...';
    if (_status == PrinterConnStatus.connecting) return 'กำลังเชื่อมต่อ...';
    if (isReadyToPrint) {
      if (_settings.transport == PrinterTransport.network) {
        return _settings.useSystemPrintFallback
            ? 'พร้อมพิมพ์ (System Print)'
            : 'พร้อมพิมพ์ (${_settings.networkHost}:${_settings.networkPort})';
      }
      final dev =
          connectedDeviceName ??
          (_settings.lastDeviceName.isNotEmpty
              ? _settings.lastDeviceName
              : _settings.transport.label);
      return 'เชื่อมต่อแล้ว: $dev';
    }
    return 'เชื่อมเครื่องพิมพ์';
  }

  /// Persists and broadcasts updated [next] settings.
  void updateSettings(PrinterSettings next) {
    _settings = next;
    _errorMessage = null;
    next.save();
    notifyListeners();
  }

  /// Opens the Web Bluetooth (BLE) device chooser and connects to a printer
  /// such as MP80C1.
  Future<bool> connectBle() async {
    _status = PrinterConnStatus.connecting;
    _errorMessage = null;
    notifyListeners();
    try {
      final name = await _driver.connectBle();
      _status = PrinterConnStatus.connected;
      _connectedDeviceName = name;
      _settings = _settings.copyWith(
        transport: PrinterTransport.ble,
        lastDeviceName: name,
      )..save();
      notifyListeners();
      return true;
    } on Object catch (e) {
      _status = PrinterConnStatus.error;
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  /// Opens the WebUSB / WebSerial chooser and connects to a wired thermal
  /// printer.
  Future<bool> connectUsb() async {
    _status = PrinterConnStatus.connecting;
    _errorMessage = null;
    notifyListeners();
    try {
      final name = await _driver.connectUsb();
      _status = PrinterConnStatus.connected;
      _connectedDeviceName = name;
      _settings = _settings.copyWith(
        transport: PrinterTransport.usb,
        lastDeviceName: name,
      )..save();
      notifyListeners();
      return true;
    } on Object catch (e) {
      _status = PrinterConnStatus.error;
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  /// Disconnects any active BLE or USB session.
  Future<void> disconnect() async {
    await _driver.disconnect();
    _status = PrinterConnStatus.disconnected;
    _connectedDeviceName = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Scans local network print endpoints on [subnetPrefix] (defaults to the
  /// first 3 octets of [PrinterSettings.networkHost] or `'192.168.1'`).
  Future<void> scanNetwork([String? subnetPrefix]) async {
    final hostParts = _settings.networkHost.trim().split('.');
    final prefix =
        subnetPrefix ??
        (hostParts.length == 4
            ? '${hostParts[0]}.${hostParts[1]}.${hostParts[2]}'
            : '192.168.1');
    _isScanningNetwork = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _discoveredPrinters = await _driver.scanNetworkPrinters(prefix);
    } on Object catch (e) {
      _errorMessage = _friendlyError(e);
    } finally {
      _isScanningNetwork = false;
      notifyListeners();
    }
  }

  /// Prints a diagnostic Thai + PromptPay QR test slip.
  Future<bool> printTestSlip(ShopConfig shop) {
    final label = statusLabel;
    return _sendJob(
      () => renderTestPrintEscPos(
        shop: shop,
        paperWidth: _settings.paperWidth,
        connectionLabel: label,
        printLogo: _settings.printLogo,
        logoDataUrl: _settings.effectiveLogoDataUrl(shop),
      ),
    );
  }

  /// Prints a customer receipt, POS QR payment slip, full tax invoice, copy,
  /// or voided bill.
  Future<bool> printBill(
    ShopConfig shop,
    BillRecord bill, {
    bool isCopy = false,
    String? replacesNo,
  }) async {
    final logoUrl = _settings.effectiveLogoDataUrl(shop);
    if (_settings.transport == PrinterTransport.network &&
        _settings.useSystemPrintFallback) {
      _status = PrinterConnStatus.printing;
      _errorMessage = null;
      notifyListeners();
      try {
        final png = await renderReceiptPngBytes(
          shop: shop,
          bill: bill,
          paperWidth: _settings.paperWidth,
          isCopy: isCopy,
          replacesNo: replacesNo,
          printLogo: _settings.printLogo,
          logoDataUrl: logoUrl,
        );
        await _driver.printHtmlReceipt(
          'บิล ${bill.no}',
          png,
          _settings.paperWidth,
        );
        _status = PrinterConnStatus.disconnected;
        notifyListeners();
        return true;
      } on Object catch (e) {
        _status = PrinterConnStatus.error;
        _errorMessage = _friendlyError(e);
        notifyListeners();
        return false;
      }
    }
    return await _sendJob(
      () => renderBillEscPos(
        shop: shop,
        bill: bill,
        paperWidth: _settings.paperWidth,
        isCopy: isCopy,
        replacesNo: replacesNo,
        printLogo: _settings.printLogo,
        logoDataUrl: logoUrl,
      ),
    );
  }

  /// Prints a combined table summary slip (`ใบสรุปยอดโต๊ะ`).
  Future<bool> printTableSummary(ShopConfig shop, TableSummarySlip summary) =>
      _sendJob(
        () => renderTableSummaryEscPos(
          shop: shop,
          summary: summary,
          paperWidth: _settings.paperWidth,
          printLogo: _settings.printLogo,
          logoDataUrl: _settings.effectiveLogoDataUrl(shop),
        ),
      );

  Future<bool> _sendJob(Future<Uint8List> Function() buildBytes) async {
    final wasHardware = _settings.transport != PrinterTransport.network;
    _status = PrinterConnStatus.printing;
    _errorMessage = null;
    notifyListeners();
    try {
      final bytes = await buildBytes();
      await _driver.sendBytes(bytes, settings: _settings);
      _status = wasHardware
          ? PrinterConnStatus.connected
          : PrinterConnStatus.disconnected;
      notifyListeners();
      return true;
    } on Object catch (e) {
      _status = PrinterConnStatus.error;
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst(RegExp(r'^StateError:\s*'), '');
    if (raw.contains('NotFoundError') || raw.contains('User cancelled')) {
      return 'ยกเลิกการเลือกเครื่องพิมพ์';
    }
    return raw;
  }
}
