import 'package:app/domain/models.dart';
import 'package:app/domain/order_calc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same cases as `calc_bill_amounts` in `supabase/tests/sales_rpc_test.sql`.
/// Amounts are satang; a change here must also change the SQL test.
void main() {
  const cases =
      <
        ({
          String name,
          int subtotal,
          double servicePct,
          String vatMode,
          double vatRate,
          String rounding,
          int service,
          int vat,
          int roundingAmount,
          int total,
        })
      >[
        (
          name: 'no VAT',
          subtotal: 59800,
          servicePct: 0,
          vatMode: 'none',
          vatRate: 7,
          rounding: 'down',
          service: 0,
          vat: 0,
          roundingAmount: 0,
          total: 59800,
        ),
        (
          name: 'excluded, no rounding',
          subtotal: 59800,
          servicePct: 0,
          vatMode: 'excluded',
          vatRate: 7,
          rounding: 'none',
          service: 0,
          vat: 4186,
          roundingAmount: 0,
          total: 63986,
        ),
        (
          name: 'excluded, round down',
          subtotal: 59800,
          servicePct: 0,
          vatMode: 'excluded',
          vatRate: 7,
          rounding: 'down',
          service: 0,
          vat: 4180,
          roundingAmount: -86,
          total: 63900,
        ),
        (
          name: 'included',
          subtotal: 59800,
          servicePct: 0,
          vatMode: 'included',
          vatRate: 7,
          rounding: 'down',
          service: 0,
          vat: 3912,
          roundingAmount: 0,
          total: 59800,
        ),
        (
          name: 'service, round down',
          subtotal: 29950,
          servicePct: 10,
          vatMode: 'none',
          vatRate: 7,
          rounding: 'down',
          service: 2995,
          vat: 0,
          roundingAmount: -45,
          total: 32900,
        ),
        (
          name: 'service + excluded',
          subtotal: 29950,
          servicePct: 10,
          vatMode: 'excluded',
          vatRate: 7,
          rounding: 'none',
          service: 2995,
          vat: 2306,
          roundingAmount: 0,
          total: 35251,
        ),
        (
          name: 'included uses rounded total',
          subtotal: 10050,
          servicePct: 0,
          vatMode: 'included',
          vatRate: 7,
          rounding: 'down',
          service: 0,
          vat: 654,
          roundingAmount: -50,
          total: 10000,
        ),
        (
          name: 'half satang rounds up',
          subtotal: 150,
          servicePct: 1,
          vatMode: 'none',
          vatRate: 7,
          rounding: 'none',
          service: 2,
          vat: 0,
          roundingAmount: 0,
          total: 152,
        ),
        (
          name: 'zero VAT rate',
          subtotal: 10000,
          servicePct: 0,
          vatMode: 'excluded',
          vatRate: 0,
          rounding: 'none',
          service: 0,
          vat: 0,
          roundingAmount: 0,
          total: 10000,
        ),
      ];

  for (final c in cases) {
    test('calcOrder matches SQL: ${c.name}', () {
      final order = calcOrder(
        ShopConfig(
          servicePct: c.servicePct,
          vatMode: c.vatMode,
          vatRate: c.vatRate,
          rounding: c.rounding,
        ),
        null,
        0,
        0,
        0,
        <AddonLineInput>[
          AddonLineInput(
            addon: AddonItem(
              id: 'x',
              name: 'x',
              category: '',
              price: c.subtotal,
              cost: 0,
              stock: 0,
            ),
            qty: 1,
          ),
        ],
      );

      expect(order.service, c.service);
      expect(order.vat, c.vat);
      expect(order.rounding, c.roundingAmount);
      expect(order.total, c.total);
    });
  }
}
