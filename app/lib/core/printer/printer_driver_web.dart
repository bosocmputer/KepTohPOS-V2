import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:app/core/printer/printer_driver.dart';
import 'package:app/core/printer/printer_models.dart';

/// Standard thermal printer BLE GATT Service UUIDs (MP80C1, Xprinter, RPP300,
/// HM-10, ISSC/Microchip, Star/Rongta, Paperang).
const List<String> kBlePrinterServiceUuids = <String>[
  '000018f0-0000-1000-8000-00805f9b34fb',
  '0000ff00-0000-1000-8000-00805f9b34fb',
  '0000ffe0-0000-1000-8000-00805f9b34fb',
  '49535343-fe7d-4ae5-8fa9-9fafd205e455',
  'e7810a71-73ae-499d-8c15-faa9aef0c3f2',
  '0000ae30-0000-1000-8000-00805f9b34fb',
];

PrinterPlatformDriver createPrinterPlatformDriver() =>
    WebPrinterPlatformDriver();

/// Browser implementation of [PrinterPlatformDriver] using Web Bluetooth,
/// WebUSB / WebSerial, Fetch LAN HTTP POST, and CSS `@page` System Print.
class WebPrinterPlatformDriver implements PrinterPlatformDriver {
  JSObject? _bleDevice;
  JSObject? _bleServer;
  JSObject? _bleWriteChar;
  bool _bleNoResp = false;
  JSObject? _usbDevice;
  int _usbEndpointOut = 1;
  JSObject? _serialPort;
  String? _connectedName;

  JSObject get _nav => globalContext['navigator']! as JSObject;

  Future<T> _call<T extends JSAny?>(
    JSObject t,
    String m, [
    JSAny? a1,
    JSAny? a2,
  ]) =>
      (a2 != null
              ? t.callMethod<JSPromise<T>>(m.toJS, a1, a2)
              : a1 != null
              ? t.callMethod<JSPromise<T>>(m.toJS, a1)
              : t.callMethod<JSPromise<T>>(m.toJS))
          .toDart;

  List<JSObject> _list(JSObject? obj, String key) =>
      (obj?[key] as JSArray<JSObject>?)?.toDart ?? const <JSObject>[];

  @override
  bool get isBleSupported => _nav.has('bluetooth');
  @override
  bool get isUsbSupported => _nav.has('usb') || _nav.has('serial');
  @override
  bool get isConnected =>
      _bleWriteChar != null || _usbDevice != null || _serialPort != null;
  @override
  String? get connectedName => _connectedName;

  @override
  Future<String> connectBle() async {
    if (!isBleSupported) throw StateError('เบราว์เซอร์ไม่รองรับ Web Bluetooth');
    await disconnect();
    final bt = _nav['bluetooth']! as JSObject;
    final opts = <String, Object>{
      'acceptAllDevices': true,
      'optionalServices': kBlePrinterServiceUuids,
    }.jsify()!;
    final dev = await _call<JSObject>(bt, 'requestDevice', opts);
    final srv = await _call<JSObject>(dev['gatt']! as JSObject, 'connect');
    final svcs = await _call<JSArray<JSObject>>(srv, 'getPrimaryServices');

    JSObject? found;
    var noResp = false;
    for (final svc in svcs.toDart) {
      final chars = await _call<JSArray<JSObject>>(svc, 'getCharacteristics');
      for (final ch in chars.toDart) {
        final props = ch['properties'] as JSObject?;
        if (props == null) continue;
        final nr =
            (props['writeWithoutResponse'] as JSBoolean?)?.toDart ?? false;
        final wr = (props['write'] as JSBoolean?)?.toDart ?? false;
        if (nr || wr) {
          found = ch;
          noResp = nr;
          if (nr) break;
        }
      }
      if (found != null && noResp) break;
    }
    if (found == null) {
      throw StateError('ไม่พบช่องทางเขียนข้อมูล (GATT Write Characteristic)');
    }
    final name = (dev['name'] as JSString?)?.toDart.trim() ?? '';
    _bleDevice = dev;
    _bleServer = srv;
    _bleWriteChar = found;
    _bleNoResp = noResp;
    return _connectedName = name.isNotEmpty ? name : 'MP80C1 Bluetooth';
  }

  @override
  Future<String> connectUsb() async {
    if (!isUsbSupported) throw StateError('ไม่รองรับ WebUSB หรือ WebSerial');
    await disconnect();
    if (_nav.has('usb')) {
      try {
        return await _connectWebUsb();
      } on Object {
        if (!_nav.has('serial')) rethrow;
      }
    }
    final serial = _nav['serial']! as JSObject;
    final empty = <String, Object>{}.jsify();
    final baud = <String, Object>{'baudRate': 115200}.jsify();
    final port = await _call<JSObject>(serial, 'requestPort', empty);
    await _call<JSAny?>(port, 'open', baud);
    _serialPort = port;
    return _connectedName = 'USB Serial (115200 bps)';
  }

  Future<String> _connectWebUsb() async {
    final usb = _nav['usb']! as JSObject;
    final opts = <String, Object>{'filters': const <Object>[]}.jsify();
    final dev = await _call<JSObject>(usb, 'requestDevice', opts);
    await _call<JSAny?>(dev, 'open');
    if (dev['configuration'] == null) {
      await _call<JSAny?>(dev, 'selectConfiguration', 1.toJS);
    }
    final cfg = dev['configuration'] as JSObject?;
    var ifaceNum = 0;
    var outEp = 1;
    for (final iface in _list(cfg, 'interfaces')) {
      final numJs = iface['interfaceNumber'] as JSNumber?;
      for (final alt in _list(iface, 'alternates')) {
        for (final ep in _list(alt, 'endpoints')) {
          if ((ep['direction'] as JSString?)?.toDart == 'out') {
            ifaceNum = numJs?.toDartInt ?? 0;
            outEp = (ep['endpointNumber'] as JSNumber?)?.toDartInt ?? 1;
            break;
          }
        }
      }
    }
    await _call<JSAny?>(dev, 'claimInterface', ifaceNum.toJS);
    final prod = (dev['productName'] as JSString?)?.toDart.trim() ?? '';
    _usbDevice = dev;
    _usbEndpointOut = outEp;
    return _connectedName = prod.isNotEmpty ? prod : 'MP80C1 USB Printer';
  }

  @override
  Future<void> disconnect() async {
    try {
      _bleServer?.callMethod<JSAny?>('disconnect'.toJS);
      if (_usbDevice != null) await _call<JSAny?>(_usbDevice!, 'close');
      if (_serialPort != null) await _call<JSAny?>(_serialPort!, 'close');
    } on Object {
      // Ignore already-closed handle errors.
    } finally {
      _bleDevice = _bleServer = _bleWriteChar = _usbDevice = _serialPort = null;
      _connectedName = null;
    }
  }

  @override
  Future<void> sendBytes(Uint8List data, {required PrinterSettings settings}) =>
      switch (settings.transport) {
        PrinterTransport.ble => _sendBle(data, settings),
        PrinterTransport.usb => _sendUsb(data),
        PrinterTransport.network => _sendNetwork(data, settings),
      };

  Future<void> _sendBle(Uint8List data, PrinterSettings settings) async {
    if (_bleWriteChar == null || _bleDevice == null) await connectBle();
    final ch = _bleWriteChar!;
    final step = settings.chunkSize.clamp(20, 512);
    final delay = settings.chunkDelayMs.clamp(0, 200);
    for (var i = 0; i < data.length; i += step) {
      final end = math.min(i + step, data.length);
      final slice = Uint8List.fromList(data.sublist(i, end)).toJS;
      if (_bleNoResp) {
        try {
          await _call<JSAny?>(ch, 'writeValueWithoutResponse', slice);
        } on Object {
          await _call<JSAny?>(ch, 'writeValue', slice);
        }
      } else {
        await _call<JSAny?>(ch, 'writeValue', slice);
      }
      if (delay > 0 && end < data.length) {
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
    }
  }

  Future<void> _sendUsb(Uint8List data) async {
    if (_usbDevice == null && _serialPort == null) await connectUsb();
    if (_usbDevice != null) {
      final ep = _usbEndpointOut.toJS;
      for (var i = 0; i < data.length; i += 4096) {
        final end = math.min(i + 4096, data.length);
        final chunk = Uint8List.fromList(data.sublist(i, end)).toJS;
        await _call<JSAny?>(_usbDevice!, 'transferOut', ep, chunk);
      }
      return;
    }
    final writable = _serialPort!['writable']! as JSObject;
    final writer = writable.callMethod<JSObject>('getWriter'.toJS);
    try {
      await _call<JSAny?>(writer, 'write', Uint8List.fromList(data).toJS);
    } finally {
      writer.callMethod<JSAny?>('releaseLock'.toJS);
    }
  }

  Future<void> _sendNetwork(Uint8List data, PrinterSettings settings) async {
    final u = 'http://${settings.networkHost.trim()}:${settings.networkPort}/';
    final init = <String, Object>{
      'method': 'POST',
      'mode': 'no-cors',
      'headers': <String, String>{'Content-Type': 'application/octet-stream'},
      'body': Uint8List.fromList(data).toJS,
    }.jsify()!;
    await _call<JSAny?>(
      globalContext,
      'fetch',
      u.toJS,
      init,
    ).timeout(const Duration(seconds: 4));
  }

  @override
  Future<List<DiscoveredNetworkPrinter>> scanNetworkPrinters(
    String subnetPrefix,
  ) async {
    final p = subnetPrefix.trim().isEmpty ? '192.168.1' : subnetPrefix.trim();
    final targets = <(String, int, String)>[
      ('127.0.0.1', 9100, 'Local Print Bridge (127.0.0.1:9100)'),
      ('localhost', 8000, 'Local ESC/POS Agent (localhost:8000)'),
      ('$p.100', 9100, 'MP80C1 LAN Default ($p.100:9100)'),
      ('$p.200', 9100, 'Thermal Printer ($p.200:9100)'),
    ];
    final found = <DiscoveredNetworkPrinter>[];
    final init = <String, Object>{'method': 'GET', 'mode': 'no-cors'}.jsify();
    const wait = Duration(milliseconds: 600);
    for (final (h, port, lbl) in targets) {
      try {
        final u = 'http://$h:$port/'.toJS;
        await _call<JSAny?>(globalContext, 'fetch', u, init).timeout(wait);
        found.add(DiscoveredNetworkPrinter(host: h, port: port, label: lbl));
      } on Object {
        // Ignore unreachable host.
      }
    }
    return found;
  }

  @override
  Future<void> printHtmlReceipt(
    String title,
    Uint8List pngBytes,
    PaperWidth width,
  ) async {
    final b64 = base64Encode(pngBytes);
    final mm = width.mm;
    final html =
        '<!DOCTYPE html><html><head><title>$title</title> '
        '<style>@page{size:${mm}mm auto;margin:0}body{margin:0} '
        'img{width:${mm}mm;max-width:100%;display:block}</style></head><body> '
        '<img src="data:image/png;base64,$b64" '
        'onload="window.focus();window.print();"/></body></html>';
    final win = globalContext.callMethod<JSObject?>(
      'open'.toJS,
      ''.toJS,
      '_blank'.toJS,
      'width=420,height=640'.toJS,
    );
    if (win == null) return;
    (win['document']! as JSObject)
      ..callMethod<JSAny?>('open'.toJS)
      ..callMethod<JSAny?>('write'.toJS, html.toJS)
      ..callMethod<JSAny?>('close'.toJS);
  }
}
