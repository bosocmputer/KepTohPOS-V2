import 'package:app/core/data/supabase/supabase_row_mappers.dart';
import 'package:app/domain/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads one business day's bills and lines, for days older than the raw
/// window the snapshot keeps. Line costs only come with a manager [token].
Future<List<BillRecord>> loadDayBills(
  SupabaseClient client,
  String shopId,
  String date, {
  String? token,
  bool readsCosts = false,
}) async {
  final bills = await client
      .from('bills')
      .select()
      .eq('shop_id', shopId)
      .eq('business_date', date)
      .order('at', ascending: true);
  final lines = await client
      .from('bill_lines')
      .select(
        'id, shop_id, bill_id, line_no, type, item_id, name, qty, price, '
        'bills!inner(business_date)',
      )
      .eq('shop_id', shopId)
      .eq('bills.business_date', date)
      .order('id', ascending: true);
  final costs = <String, int>{};
  if (token != null && readsCosts) {
    final extra = await client.rpc<Map<String, dynamic>>(
      'get_manager_data',
      params: <String, dynamic>{
        'p_shop_id': shopId,
        'p_from': date,
        'p_to': date,
        'p_token': token,
      },
    );
    for (final c
        in ((extra['bill_line_costs'] as List<dynamic>?) ?? []).cast<Row>()) {
      costs['${c['bill_id']}#${c['line_no']}'] = (c['cost'] as num).toInt();
    }
  }
  final byBill = <String, List<Row>>{};
  for (final l in lines) {
    (byBill[l['bill_id'] as String] ??= <Row>[]).add(l);
  }
  return bills.map((b) {
    final id = b['id'] as String;
    final ls = (byBill[id] ?? <Row>[])
      ..sort((x, y) => (x['line_no'] as int).compareTo(y['line_no'] as int));
    return billFromRow(
      b,
      ls.map((l) => lineFromRow(l, costs['$id#${l['line_no']}'])).toList(),
    );
  }).toList();
}
