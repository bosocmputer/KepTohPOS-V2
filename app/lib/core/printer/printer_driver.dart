import 'dart:typed_data';

import 'package:app/core/printer/printer_driver_stub.dart'
    if (dart.library.js_interop) 'package:app/core/printer/printer_driver_web.dart'
    as impl;
import 'package:app/core/printer/printer_models.dart';

export 'package:app/core/printer/printer_driver_stub.dart'
    if (dart.library.js_interop) 'package:app/core/printer/printer_driver_web.dart';

/// Platform abstraction for thermal printer hardware transports:
/// Web Bluetooth (BLE), Direct USB (WebUSB / WebSerial), and IP Network /
/// System Print fallback.
abstract class PrinterPlatformDriver {
  factory() => impl.createPrinterPlatformDriver();

  /// Whether Web Bluetooth (`navigator.bluetooth`) is available.
  bool get isBleSupported;

  /// Whether WebUSB (`navigator.usb`) or WebSerial (`navigator.serial`) is
  /// available.
  bool get isUsbSupported;

  /// Whether an active hardware session (BLE GATT or USB/Serial) is open.
  bool get isConnected;

  /// Display name of the currently connected BLE or USB printer, if any.
  String? get connectedName;

  /// Requests and connects to a Bluetooth Low Energy thermal printer (such as
  /// MP80C1), returning the connected device name.
  Future<String> connectBle();

  /// Requests and connects to a USB or USB-Serial thermal printer, returning
  /// the connected device/port name.
  Future<String> connectUsb();

  /// Closes any active BLE or USB/Serial connection.
  Future<void> disconnect();

  /// Transmits raw ESC/POS [data] over the transport selected in [settings].
  Future<void> sendBytes(Uint8List data, {required PrinterSettings settings});

  /// Scans local print gateway / printer HTTP endpoints on [subnetPrefix]
  /// (e.g. `'192.168.1'`).
  Future<List<DiscoveredNetworkPrinter>> scanNetworkPrinters(
    String subnetPrefix,
  );

  /// Opens a print-styled HTML receipt window (`@page { size: 80mm auto }`)
  /// with the rendered [pngBytes] and triggers `window.print()`.
  Future<void> printHtmlReceipt(
    String title,
    Uint8List pngBytes,
    PaperWidth width,
  );
}
