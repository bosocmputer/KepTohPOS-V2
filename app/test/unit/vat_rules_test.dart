import 'package:app/domain/models.dart';
import 'package:app/domain/order_calc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same cases as `supabase/tests/vat_rules_test.sql` (satang). A change here
/// must also change the SQL test.
CalculatedOrder _calc(int subtotal, String vatMode, String rounding) =>
    calcOrder(
      ShopConfig(vatMode: vatMode, rounding: rounding),
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
            price: subtotal,
            cost: 0,
            stock: 0,
          ),
          qty: 1,
        ),
      ],
    );

void main() {
  void expectOrder(CalculatedOrder o, int vat, int rounding, int total) {
    expect((o.vat, o.rounding, o.total), (vat, rounding, total));
  }

  test('excluded + round down: VAT from rounded total', () {
    final o = _calc(59800, 'excluded', 'down');
    expectOrder(o, 4180, -86, 63900);
    expect(o.total - o.vat, 59720);
  });
  test('excluded, no rounding unchanged', () {
    expectOrder(_calc(59800, 'excluded', 'none'), 4186, 0, 63986);
  });
  test('excluded, rounding does not change total: VAT unchanged', () {
    expectOrder(_calc(60000, 'excluded', 'down'), 4200, 0, 64200);
  });
  test('included unchanged', () {
    expectOrder(_calc(59800, 'included', 'down'), 3912, 0, 59800);
  });
  test('included + round down: VAT from rounded total', () {
    expectOrder(_calc(59850, 'included', 'down'), 3912, -50, 59800);
  });
  test('none unchanged', () {
    expectOrder(_calc(59800, 'none', 'down'), 0, 0, 59800);
  });
}
