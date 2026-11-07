import 'package:app/domain/roles.dart';

/// Current `PosState.version`. Version 3 stores recorded money as integer
/// satang; earlier versions stored baht as decimals.
const int kPosStateVersion = 3;

/// Returns [json] with money converted to satang when it was saved by an older
/// version (browser `localStorage` or an exported file). Already-migrated data
/// is returned untouched, so calling this twice cannot multiply amounts again.
Map<String, dynamic> migrateStateJson(Map<String, dynamic> json) {
  final version = (json['version'] as num?)?.toInt() ?? 2;
  if (version >= kPosStateVersion) return json;

  final next = Map<String, dynamic>.of(json);
  next['version'] = kPosStateVersion;
  next['shop'] = _convert(json['shop'], const <String>['defaultFloat']);
  next['packages'] = _convertList(json['packages'], const <String>[
    'adultPrice',
    'childPrice',
  ]);
  next['addons'] = _convertList(json['addons'], const <String>[
    'price',
    'cost',
  ]);
  next['ingredients'] = _convertList(json['ingredients'], const <String>[
    'lastCost',
  ]);
  next['fixedCosts'] = _convertList(json['fixedCosts'], const <String>[
    'amount',
  ]);
  next['expenses'] = _convertList(json['expenses'], const <String>['amount']);
  next['shifts'] = _convertList(json['shifts'], const <String>[
    'floatAmount',
    'float',
    'counted',
  ]);
  next['sales'] = _convertNested(
    json['sales'],
    const <String>[
      'subtotal',
      'service',
      'vat',
      'rounding',
      'total',
      'received',
      'change',
    ],
    const <String>['price', 'cost'],
  );
  next['purchases'] = _convertNested(
    json['purchases'],
    const <String>[],
    const <String>['total'],
  );
  final stock = json['initialStock'];
  if (stock is Map<String, dynamic>) {
    next['initialStock'] = stock.map(
      (id, lot) => MapEntry(id, _convert(lot, const <String>['cost'])),
    );
  }
  next.removeWhere((key, value) => value == null && !json.containsKey(key));
  return next;
}

Object? _convert(Object? value, List<String> keys) {
  if (value is! Map<String, dynamic>) return value;
  final next = Map<String, dynamic>.of(value);
  for (final key in keys) {
    final amount = next[key];
    if (amount is num) next[key] = satangFromBaht(amount);
  }
  return next;
}

Object? _convertList(Object? value, List<String> keys) => value is List<dynamic>
    ? value.map((item) => _convert(item, keys)).toList()
    : value;

Object? _convertNested(
  Object? value,
  List<String> keys,
  List<String> lineKeys,
) {
  if (value is! List<dynamic>) return value;
  return value.map((item) {
    final next = _convert(item, keys);
    if (next is Map<String, dynamic>) {
      next['lines'] = _convertList(next['lines'], lineKeys);
      if (next['lines'] == null) next.remove('lines');
    }
    return next;
  }).toList();
}
