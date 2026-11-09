import 'package:app/core/data/supabase/supabase_pos_base.dart';
import 'package:app/domain/domain.dart';

/// Full tax invoice (ม.86/4) issuing through a server RPC; online only.
mixin SupabasePosInvoiceCommands on SupabasePosBase implements PosRepository {
  @override
  Future<BillRecord> issueFullInvoice({
    required String billId,
    required String buyerName,
    required String buyerAddress,
    String? buyerTaxId,
    String? buyerBranch,
  }) async {
    final newBillId = newId();
    await staffRpc<Object?>('issue_full_invoice', <String, dynamic>{
      'p_shop_id': shopId,
      'p_bill_id': billId,
      'p_new_id': newBillId,
      'p_buyer_name': buyerName,
      'p_buyer_address': buyerAddress,
      'p_buyer_tax_id': ?buyerTaxId,
      'p_buyer_branch': ?buyerBranch,
    });
    final state = await reload();
    return state.sales.firstWhere((b) => b.id == newBillId);
  }
}
