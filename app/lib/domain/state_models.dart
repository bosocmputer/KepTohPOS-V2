import 'package:app/domain/entities.dart';

export 'package:app/domain/pos_state.dart';

/// Head counts for adult (`a`), child (`c`), and free toddler (`f`).
class HeadsCount {
  new({this.a = 0, this.c = 0, this.f = 0});

  int a;
  int c;
  int f;

  int operator [](String key) => switch (key) {
    'a' => a,
    'c' => c,
    'f' => f,
    _ => 0,
  };

  void operator []=(String key, int value) {
    switch (key) {
      case 'a':
        a = value;
      case 'c':
        c = value;
      case 'f':
        f = value;
    }
  }

  HeadsCount copy() => HeadsCount(a: a, c: c, f: f);
}

/// Input line for `calcOrder` (`{ addon, qty }`).
class AddonLineInput {
  const new({required this.addon, required this.qty});

  final AddonItem addon;
  final int qty;
}

/// Calculated order line item (`buffet` or `addon`).
class OrderLineItem {
  const new({
    required this.type,
    required this.name,
    required this.qty,
    required this.price,
    this.id,
    this.cost,
  });

  final String type;
  final String? id;
  final String name;
  final int qty;
  final double price;
  final double? cost;
}

/// Result of `calcOrder` / `orderOf`.
class CalculatedOrder {
  const new({
    required this.lines,
    required this.subtotal,
    required this.service,
    required this.vat,
    required this.rounding,
    required this.total,
    required this.heads,
  });

  final List<OrderLineItem> lines;
  final double subtotal;
  final double service;
  final double vat;
  final double rounding;
  final double total;
  final HeadsCount heads;
}

/// Aggregated table/cart quantities (`{ a, c, f, ad }`).
class TableTotals {
  new({this.a = 0, this.c = 0, this.f = 0, Map<String, int>? ad})
    : ad = ad ?? <String, int>{};

  int a;
  int c;
  int f;
  final Map<String, int> ad;

  int headOf(String key) => switch (key) {
    'a' => a,
    'c' => c,
    'f' => f,
    _ => 0,
  };
}

/// A sent order round in eat-before-paying mode.
class TableRound {
  new({
    required this.id,
    required this.at,
    required this.staffId,
    required this.a,
    required this.c,
    required this.f,
    Map<String, int>? ad,
  }) : ad = ad ?? <String, int>{};

  final String id;
  final String at;
  final String staffId;
  final int a;
  final int c;
  final int f;
  final Map<String, int> ad;
}

/// Adjustment reducing a sent item (`o.adjusts` / `o.log`).
class TableAdjustment {
  const new({
    required this.id,
    required this.at,
    required this.by,
    required this.byName,
    required this.reason,
    required this.kind,
    required this.key,
    required this.qty,
  });

  final String id;
  final String at;
  final String by;
  final String byName;
  final String reason;
  final String kind;
  final String key;
  final int qty;
}

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

  final String openedAt;
  final String packageId;
  String timing;
  String notes;
  final List<String> billIds;
  final HeadsCount heads;
  List<TableRound> rounds;
  List<TableAdjustment> adjusts;
  final List<TableAdjustment> log;
}

/// Flattened sent line returned by `sentLines`.
class SentLineItem {
  const new({
    required this.kind,
    required this.key,
    required this.name,
    required this.qty,
    required this.price,
  });

  final String kind;
  final String key;
  final String name;
  final int qty;
  final double price;
}

/// Timer status returned by `tableTimer`.
class TableTimerStatus {
  const new({
    required this.mins,
    required this.limit,
    required this.late,
    required this.text,
  });

  final int mins;
  final int limit;
  final bool late;
  final String text;
}
