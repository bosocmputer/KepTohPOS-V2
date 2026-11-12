import 'dart:convert';

import 'package:app/core/data/web_storage.dart';
import 'package:app/domain/shop_config.dart';
import 'package:equatable/equatable.dart';

/// Browser `localStorage` key for persisted thermal printer configuration.
const String kPrinterSettingsStorageKey = 'keptoh-printer-settings-v1';

/// Connection transport mode for thermal receipt printers (e.g. MP80C1).
enum PrinterTransport {
  ble(
    id: 'ble',
    label: 'Bluetooth (BLE)',
    subtitle: 'ไร้สายผ่าน Web Bluetooth สำหรับ iPad / Android / Desktop',
  ),
  usb(
    id: 'usb',
    label: 'สายตรง (USB / Serial)',
    subtitle: 'เสียบสาย USB-C / USB-A เข้าเครื่องผ่าน WebUSB หรือ WebSerial',
  ),
  network(
    id: 'network',
    label: 'ผ่านเน็ต / Wi-Fi (IP / System Print)',
    subtitle: 'พิมพ์ผ่าน IP LAN/Wi-Fi หรือหน้าต่างพิมพ์ของระบบ (AirPrint/OS)',
  );

  new({required this.id, required this.label, required this.subtitle});

  final String id;
  final String label;
  final String subtitle;

  static PrinterTransport fromId(String? raw) =>
      PrinterTransport.values
          .where((e) => e.id == raw || e.name == raw)
          .firstOrNull ??
      PrinterTransport.ble;
}

/// Thermal paper roll width and printable raster dot count at 203 DPI.
enum PaperWidth {
  mm80(dots: 576, label: '80 มม. (มาตรฐาน)'),
  mm58(dots: 384, label: '58 มม. (ขนาดเล็ก)');

  new({required this.dots, required this.label});

  final int dots;
  final String label;

  int get mm => this == PaperWidth.mm80 ? 80 : 58;

  static PaperWidth fromName(String? raw) =>
      raw == 'mm58' || raw == '58' ? PaperWidth.mm58 : PaperWidth.mm80;
}

/// Live connection/printing status of the thermal printer service.
enum PrinterConnStatus { disconnected, connecting, connected, printing, error }

/// A discovered local network print endpoint or gateway.
class DiscoveredNetworkPrinter extends Equatable {
  const new({required this.host, required this.port, required this.label});

  final String host;
  final int port;
  final String label;

  String get address => '$host:$port';

  @override
  List<Object?> get props => <Object?>[host, port, label];
}

/// User-configurable thermal printer settings persisted in `localStorage`.
class PrinterSettings extends Equatable {
  const new({
    this.transport = PrinterTransport.ble,
    this.paperWidth = PaperWidth.mm80,
    this.autoPrintOnSettle = false,
    this.networkHost = '192.168.1.100',
    this.networkPort = 9100,
    this.useSystemPrintFallback = false,
    this.lastDeviceName = '',
    this.chunkSize = 180,
    this.chunkDelayMs = 18,
    this.printLogo = true,
    this.customLogoDataUrl = '',
  });

  /// Accepts either a decoded `Map<String, dynamic>` or a JSON `String`.
  factory fromJson(Object? raw) {
    Map<String, dynamic> map;
    if (raw is String) {
      if (raw.trim().isEmpty) return const PrinterSettings();
      try {
        final decoded = jsonDecode(raw);
        map = decoded is Map<String, dynamic>
            ? decoded
            : const <String, dynamic>{};
      } on Object {
        return const PrinterSettings();
      }
    } else if (raw is Map<String, dynamic>) {
      map = raw;
    } else {
      return const PrinterSettings();
    }
    return PrinterSettings(
      transport: PrinterTransport.fromId(map['transport'] as String?),
      paperWidth: PaperWidth.fromName(map['paperWidth'] as String?),
      autoPrintOnSettle: (map['autoPrintOnSettle'] as bool?) ?? false,
      networkHost: (map['networkHost'] as String?)?.trim().isNotEmpty ?? false
          ? (map['networkHost'] as String).trim()
          : '192.168.1.100',
      networkPort: (map['networkPort'] as num?)?.toInt() ?? 9100,
      useSystemPrintFallback: (map['useSystemPrintFallback'] as bool?) ?? false,
      lastDeviceName: (map['lastDeviceName'] as String?) ?? '',
      chunkSize: ((map['chunkSize'] as num?)?.toInt() ?? 180).clamp(20, 512),
      chunkDelayMs: ((map['chunkDelayMs'] as num?)?.toInt() ?? 18).clamp(
        0,
        200,
      ),
      printLogo: (map['printLogo'] as bool?) ?? true,
      customLogoDataUrl: (map['customLogoDataUrl'] as String?) ?? '',
    );
  }

  factory load() =>
      PrinterSettings.fromJson(readWebLocalStorage(kPrinterSettingsStorageKey));

  final PrinterTransport transport;
  final PaperWidth paperWidth;
  final bool autoPrintOnSettle;
  final String networkHost;
  final int networkPort;
  final bool useSystemPrintFallback;
  final String lastDeviceName;
  final int chunkSize;
  final int chunkDelayMs;
  final bool printLogo;
  final String customLogoDataUrl;

  String effectiveLogoDataUrl(ShopConfig shop) =>
      customLogoDataUrl.isNotEmpty ? customLogoDataUrl : shop.logoDataUrl;

  PrinterSettings copyWith({
    PrinterTransport? transport,
    PaperWidth? paperWidth,
    bool? autoPrintOnSettle,
    String? networkHost,
    int? networkPort,
    bool? useSystemPrintFallback,
    String? lastDeviceName,
    int? chunkSize,
    int? chunkDelayMs,
    bool? printLogo,
    String? customLogoDataUrl,
  }) => PrinterSettings(
    transport: transport ?? this.transport,
    paperWidth: paperWidth ?? this.paperWidth,
    autoPrintOnSettle: autoPrintOnSettle ?? this.autoPrintOnSettle,
    networkHost: networkHost ?? this.networkHost,
    networkPort: networkPort ?? this.networkPort,
    useSystemPrintFallback:
        useSystemPrintFallback ?? this.useSystemPrintFallback,
    lastDeviceName: lastDeviceName ?? this.lastDeviceName,
    chunkSize: chunkSize ?? this.chunkSize,
    chunkDelayMs: chunkDelayMs ?? this.chunkDelayMs,
    printLogo: printLogo ?? this.printLogo,
    customLogoDataUrl: customLogoDataUrl ?? this.customLogoDataUrl,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'transport': transport.id,
    'paperWidth': paperWidth.name,
    'autoPrintOnSettle': autoPrintOnSettle,
    'networkHost': networkHost,
    'networkPort': networkPort,
    'useSystemPrintFallback': useSystemPrintFallback,
    'lastDeviceName': lastDeviceName,
    'chunkSize': chunkSize,
    'chunkDelayMs': chunkDelayMs,
    'printLogo': printLogo,
    if (customLogoDataUrl.isNotEmpty) 'customLogoDataUrl': customLogoDataUrl,
  };

  String toJsonString() => jsonEncode(toJson());

  void save() =>
      writeWebLocalStorage(kPrinterSettingsStorageKey, toJsonString());

  @override
  List<Object?> get props => <Object?>[
    transport,
    paperWidth,
    autoPrintOnSettle,
    networkHost,
    networkPort,
    useSystemPrintFallback,
    lastDeviceName,
    chunkSize,
    chunkDelayMs,
    printLogo,
    customLogoDataUrl,
  ];
}
