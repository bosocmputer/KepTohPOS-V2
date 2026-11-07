import 'package:app/core/data/supabase/supabase_pos_base.dart';
import 'package:app/domain/domain.dart';

/// Purchases, expenses and stock counts through server RPCs.
mixin SupabasePosStockCommands on SupabasePosBase implements PosRepository {
  @override
  Future<bool> recordPurchase({
    required String date,
    required String supplierId,
    required List<PurchaseLine> lines,
    required StaffMember staff,
    required String note,
    required DateTime now,
    String? editId,
  }) async {
    final valid = lines.where((l) => l.ingId.isNotEmpty && l.qty > 0).toList();
    if (valid.isEmpty) return false;
    final ok = await staffRpc<bool>('record_purchase', <String, dynamic>{
      'p_id': editId ?? newId(),
      'p_date': date,
      'p_supplier_id': supplierId.isEmpty ? null : supplierId,
      'p_note': note,
      'p_lines': valid
          .map(
            (l) => <String, dynamic>{
              'ingredient_id': l.ingId,
              'qty': l.qty,
              'total': l.total >= 0 ? l.total : 0,
            },
          )
          .toList(),
      'p_at': now.toUtc().toIso8601String(),
      'p_is_edit': editId != null,
    });
    if (ok) await reload();
    return ok;
  }

  @override
  Future<bool> removePurchase({
    required String purchaseId,
    required StaffMember staff,
  }) async {
    final ok = await staffRpc<bool>('remove_purchase', <String, dynamic>{
      'p_id': purchaseId,
    });
    if (ok) await reload();
    return ok;
  }

  @override
  Future<bool> recordExpenses({
    required String date,
    required List<ExpenseDraftLine> lines,
    required StaffMember staff,
    required DateTime now,
    String? editId,
  }) async {
    final valid = lines
        .where((l) => l.typeId.isNotEmpty && l.amount > 0)
        .toList();
    if (valid.isEmpty) return false;
    final bool ok;
    if (editId != null) {
      final first = valid.first;
      ok = await staffRpc<bool>('update_expense', <String, dynamic>{
        'p_id': editId,
        'p_type_id': first.typeId,
        'p_amount': first.amount,
        'p_note': first.note,
      });
    } else {
      ok = await staffRpc<bool>('record_expenses', <String, dynamic>{
        'p_date': date,
        'p_lines': valid
            .map(
              (l) => <String, dynamic>{
                'id': newId(),
                'type_id': l.typeId,
                'amount': l.amount,
                'note': l.note,
              },
            )
            .toList(),
        'p_at': now.toUtc().toIso8601String(),
      });
    }
    if (ok) await reload();
    return ok;
  }

  @override
  Future<bool> removeExpense({
    required String expenseId,
    required StaffMember staff,
  }) async {
    final ok = await staffRpc<bool>('remove_expense', <String, dynamic>{
      'p_id': expenseId,
    });
    if (ok) await reload();
    return ok;
  }

  @override
  Future<void> saveStockCount({
    required String date,
    required Map<String, String> draftValues,
  }) async {
    final counts = <String, double>{};
    for (final ing in posState.ingredients) {
      final parsed = double.tryParse(draftValues[ing.id]?.trim() ?? '');
      if (parsed != null) counts[ing.id] = roundQty(parsed, ing.unit);
    }
    await staffRpc<void>('save_stock_count', <String, dynamic>{
      'p_date': date,
      'p_counts': counts,
      'p_at': DateTime.now().toUtc().toIso8601String(),
    });
    await reload();
  }

  @override
  Future<bool> reopenDay({
    required String date,
    required StaffMember staff,
  }) async {
    final ok = await staffRpc<bool>('reopen_day', <String, dynamic>{
      'p_date': date,
    });
    if (ok) await reload();
    return ok;
  }
}
