import 'package:app/domain/entities.dart';

/// Head counts for adult (`a`), child (`c`), and free toddler (`f`).
class HeadsCount {
  new({int a = 0, int c = 0, int f = 0, bool frozen = false}) {
    _a = a;
    _c = c;
    _f = f;
    _frozen = frozen;
  }

  factory fromJson(Map<String, dynamic> json) => HeadsCount(
    a: (json['a'] as num?)?.toInt() ?? 0,
    c: (json['c'] as num?)?.toInt() ?? 0,
    f: (json['f'] as num?)?.toInt() ?? 0,
  );

  late int _a;
  late int _c;
  late int _f;
  late final bool _frozen;

  int get a => _a;
  set a(int value) {
    if (_frozen) throw UnsupportedError('Cannot modify frozen HeadsCount');
    _a = value;
  }

  int get c => _c;
  set c(int value) {
    if (_frozen) throw UnsupportedError('Cannot modify frozen HeadsCount');
    _c = value;
  }

  int get f => _f;
  set f(int value) {
    if (_frozen) throw UnsupportedError('Cannot modify frozen HeadsCount');
    _f = value;
  }

  int operator [](String key) => switch (key) {
    'a' => _a,
    'c' => _c,
    'f' => _f,
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

  HeadsCount copy() => HeadsCount(a: _a, c: _c, f: _f);

  HeadsCount freeze() => HeadsCount(a: _a, c: _c, f: _f, frozen: true);

  Map<String, dynamic> toJson() => <String, dynamic>{'a': _a, 'c': _c, 'f': _f};
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

  factory fromJson(Map<String, dynamic> json) => OrderLineItem(
    type: (json['type'] as String?) ?? 'buffet',
    id: json['id'] as String?,
    name: json['name'] as String,
    qty: (json['qty'] as num).toInt(),
    price: (json['price'] as num).toDouble(),
    cost: (json['cost'] as num?)?.toDouble(),
  );

  final String type;
  final String? id;
  final String name;
  final int qty;
  final double price;
  final double? cost;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    if (id != null) 'id': id,
    'name': name,
    'qty': qty,
    'price': price,
    if (cost != null) 'cost': cost,
  };
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

  factory fromJson(Map<String, dynamic> json) => TableRound(
    id: json['id'] as String,
    at: json['at'] as String,
    staffId: (json['staffId'] as String?) ?? '',
    a: (json['a'] as num?)?.toInt() ?? 0,
    c: (json['c'] as num?)?.toInt() ?? 0,
    f: (json['f'] as num?)?.toInt() ?? 0,
    ad: ((json['ad'] as Map<String, dynamic>?) ?? const <String, dynamic>{})
        .map((k, v) => MapEntry(k, (v as num).toInt())),
  );

  final String id;
  final String at;
  final String staffId;
  final int a;
  final int c;
  final int f;
  final Map<String, int> ad;

  TableRound copy() => TableRound(
    id: id,
    at: at,
    staffId: staffId,
    a: a,
    c: c,
    f: f,
    ad: Map<String, int>.from(ad),
  );

  TableRound freeze() => TableRound(
    id: id,
    at: at,
    staffId: staffId,
    a: a,
    c: c,
    f: f,
    ad: Map<String, int>.unmodifiable(ad),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'at': at,
    'staffId': staffId,
    'a': a,
    'c': c,
    'f': f,
    'ad': ad,
  };
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

  factory fromJson(Map<String, dynamic> json) => TableAdjustment(
    id: json['id'] as String,
    at: json['at'] as String,
    by: (json['by'] as String?) ?? '',
    byName: (json['byName'] as String?) ?? '',
    reason: (json['reason'] as String?) ?? '',
    kind: json['kind'] as String,
    key: json['key'] as String,
    qty: (json['qty'] as num).toInt(),
  );

  final String id;
  final String at;
  final String by;
  final String byName;
  final String reason;
  final String kind;
  final String key;
  final int qty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'at': at,
    'by': by,
    'byName': byName,
    'reason': reason,
    'kind': kind,
    'key': key,
    'qty': qty,
  };
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
