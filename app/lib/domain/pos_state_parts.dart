import 'package:app/domain/state_models.dart';

/// Active state of an occupied table (`openTables[tableId]`).
class OpenTableState {
  new({
    required this.openedAt,
    required this.packageId,
    this.timing = 'before',
    this.notes = '',
    List<String>? billIds,
    HeadsCount? heads,
    List<TableRound>? rounds,
    List<TableAdjustment>? adjusts,
    List<TableAdjustment>? log,
  }) : billIds = billIds ?? <String>[],
       heads = heads ?? HeadsCount(),
       rounds = rounds ?? <TableRound>[],
       adjusts = adjusts ?? <TableAdjustment>[],
       log = log ?? <TableAdjustment>[];

  factory fromJson(Map<String, dynamic> json) => OpenTableState(
    openedAt: json['openedAt'] as String,
    packageId: json['packageId'] as String,
    timing: (json['timing'] as String?) ?? 'before',
    notes: (json['notes'] as String?) ?? '',
    billIds: ((json['billIds'] as List<dynamic>?) ?? const <dynamic>[])
        .cast<String>()
        .toList(),
    heads: HeadsCount.fromJson(
      (json['heads'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    ),
    rounds: ((json['rounds'] as List<dynamic>?) ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(TableRound.fromJson)
        .toList(),
    adjusts: ((json['adjusts'] as List<dynamic>?) ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(TableAdjustment.fromJson)
        .toList(),
    log: ((json['log'] as List<dynamic>?) ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(TableAdjustment.fromJson)
        .toList(),
  );

  final String openedAt;
  final String packageId;
  String timing;
  String notes;
  final List<String> billIds;
  final HeadsCount heads;
  List<TableRound> rounds;
  List<TableAdjustment> adjusts;
  final List<TableAdjustment> log;

  OpenTableState copy() => OpenTableState(
    openedAt: openedAt,
    packageId: packageId,
    timing: timing,
    notes: notes,
    billIds: List<String>.from(billIds),
    heads: heads.copy(),
    rounds: rounds.map((r) => r.copy()).toList(),
    adjusts: List<TableAdjustment>.from(adjusts),
    log: List<TableAdjustment>.from(log),
  );

  OpenTableState freeze() => OpenTableState(
    openedAt: openedAt,
    packageId: packageId,
    timing: timing,
    notes: notes,
    billIds: List<String>.unmodifiable(billIds),
    heads: heads.freeze(),
    rounds: List<TableRound>.unmodifiable(rounds.map((r) => r.freeze())),
    adjusts: List<TableAdjustment>.unmodifiable(adjusts),
    log: List<TableAdjustment>.unmodifiable(log),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'openedAt': openedAt,
    'packageId': packageId,
    'timing': timing,
    'notes': notes,
    'billIds': billIds,
    'heads': heads.toJson(),
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'adjusts': adjusts.map((a) => a.toJson()).toList(),
    'log': log.map((l) => l.toJson()).toList(),
  };
}

/// One business day's sales totals from `get_daily_sales_totals`, standing in
/// for raw bills older than `PosState.rawFrom`. [addonCost] is `null` when the
/// caller cannot see costs.
class DailySalesTotal {
  const new({
    required this.bills,
    required this.a,
    required this.c,
    required this.f,
    required this.gross,
    required this.net,
    required this.buffetNet,
    required this.addonNet,
    this.addonCost,
  });

  factory fromJson(Map<String, dynamic> j) => DailySalesTotal(
    bills: (j['bills'] as num).toInt(),
    a: (j['a'] as num).toInt(),
    c: (j['c'] as num).toInt(),
    f: (j['f'] as num).toInt(),
    gross: (j['gross'] as num).toDouble(),
    net: (j['net'] as num).toDouble(),
    buffetNet: (j['buffetNet'] as num).toDouble(),
    addonNet: (j['addonNet'] as num).toDouble(),
    addonCost: (j['addonCost'] as num?)?.toDouble(),
  );

  final int bills;
  final int a;
  final int c;
  final int f;
  final double gross;
  final double net;
  final double buffetNet;
  final double addonNet;
  final double? addonCost;

  DailySalesTotal withoutCost() => DailySalesTotal(
    bills: bills,
    a: a,
    c: c,
    f: f,
    gross: gross,
    net: net,
    buffetNet: buffetNet,
    addonNet: addonNet,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'bills': bills,
    'a': a,
    'c': c,
    'f': f,
    'gross': gross,
    'net': net,
    'buffetNet': buffetNet,
    'addonNet': addonNet,
    'addonCost': addonCost,
  };
}

/// One business day's sales of one add-on item from `get_addon_sales`,
/// standing in for raw bills older than `PosState.rawFrom`. [cost] is `null`
/// when the caller cannot see costs.
class AddonSaleDay {
  const new({
    required this.date,
    required this.name,
    required this.qty,
    required this.rev,
    this.cost,
  });

  factory fromJson(Map<String, dynamic> j) => AddonSaleDay(
    date: j['date'] as String,
    name: j['name'] as String,
    qty: (j['qty'] as num).toInt(),
    rev: (j['rev'] as num).toDouble(),
    cost: (j['cost'] as num?)?.toDouble(),
  );

  final String date;
  final String name;
  final int qty;
  final double rev;
  final double? cost;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'date': date,
    'name': name,
    'qty': qty,
    'rev': rev,
    'cost': cost,
  };
}
