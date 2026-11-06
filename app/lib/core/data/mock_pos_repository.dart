import 'dart:async';
import 'dart:convert';

import 'package:app/domain/domain.dart';
import 'package:flutter/services.dart';

/// In-memory implementation of [PosRepository] backed by `assets/mock/*.json`
/// and `seed()`. Copies [PosState] only on [update], while [state] returns the
/// frozen read-only snapshot in O(1) without copying.
class MockPosRepository implements PosRepository {
  new({required PosState initialState, String? sessionStaffId})
    : _state = initialState.copy().freeze() {
    _sessionStaffId = sessionStaffId;
  }

  /// Creates a [MockPosRepository] from a pre-built [PosState].
  factory fromState(PosState initialState, {String? sessionStaffId}) =>
      MockPosRepository(
        initialState: initialState,
        sessionStaffId: sessionStaffId,
      );

  /// Parses the 10 JSON strings (`shop`, `packages`, `addons`, `suppliers`,
  /// `ingredients`, `tables`, `staff`, `payments`, `expense_types`,
  /// `fixed_costs`) and seeds 30 days of in-memory POS data.
  factory fromJsonStrings(
    Map<String, String> jsonByName, {
    DateTime? now,
    String? sessionStaffId,
  }) {
    Map<String, dynamic> decodeObj(String key) =>
        jsonDecode(jsonByName[key]!) as Map<String, dynamic>;
    List<Map<String, dynamic>> decodeList(String key) =>
        (jsonDecode(jsonByName[key]!) as List<dynamic>)
            .cast<Map<String, dynamic>>();

    final seeded = seed(
      shop: ShopConfig.fromJson(decodeObj('shop')),
      packages: decodeList('packages').map(PackageItem.fromJson).toList(),
      addons: decodeList('addons').map(AddonItem.fromJson).toList(),
      suppliers: decodeList('suppliers').map(SupplierItem.fromJson).toList(),
      ingredients: decodeList('ingredients')
          .map(IngredientItem.fromJson)
          .toList(),
      tables: decodeList('tables').map(DiningTable.fromJson).toList(),
      staff: decodeList('staff').map(StaffMember.fromJson).toList(),
      payments: decodeList('payments').map(PaymentMethod.fromJson).toList(),
      expenseTypes: decodeList('expense_types')
          .map(ExpenseType.fromJson)
          .toList(),
      fixedCosts: decodeList('fixed_costs')
          .map(FixedCostItem.fromJson)
          .toList(),
      now: now,
    );
    return MockPosRepository(
      initialState: seeded,
      sessionStaffId: sessionStaffId,
    );
  }

  /// Synchronous minimal fallback for widget tests that do not call
  /// `configureDependencies()` before pumping `KepTohApp`.
  factory createFallback({DateTime? now, String? sessionStaffId = 'st1'}) {
    final currentNow = now ?? DateTime(2026, 11, 4, 12);
    final state = PosState(
      startDate: '2026-10-05',
      shop: const ShopConfig(
        name: 'จ่าโบ้หมูกะทะ',
        address:
            '95/7 Faham , Muang Chiang Mai, Chiang Mai, Thailand, Chiang Mai',
        phone: '082 929 5566',
        promptpay: '0829295566',
      ),
      packages: const <PackageItem>[
        PackageItem(
          id: 'pk1',
          name: 'บุฟเฟต์หมู',
          adultPrice: 199,
          childPrice: 99,
        ),
        PackageItem(
          id: 'pk2',
          name: 'หมู + ทะเล',
          adultPrice: 279,
          childPrice: 139,
          timeLimit: 120,
        ),
      ],
      addons: <AddonItem>[
        AddonItem(
          id: 'ad1',
          name: 'น้ำเปล่า',
          category: 'เครื่องดื่ม',
          price: 15,
          cost: 6,
          stock: 96,
        ),
      ],
      suppliers: const <SupplierItem>[SupplierItem(id: 'sup1', name: 'ตลาดสด')],
      ingredients: const <IngredientItem>[],
      tables: const <DiningTable>[
        DiningTable(id: 't1', name: 'A1', seats: 4, zone: 'ในร้าน'),
      ],
      staff: const <StaffMember>[
        StaffMember(id: 'st1', name: 'อัย', role: 'owner', pin: '1234'),
        StaffMember(id: 'st2', name: 'ไอติม', role: 'manager', pin: '2222'),
        StaffMember(id: 'st3', name: 'เนส', role: 'cashier', pin: '1111'),
      ],
      payments: const <PaymentMethod>[
        PaymentMethod(id: 'pm1', name: 'เงินสด', type: 'cash'),
        PaymentMethod(id: 'pm2', name: 'QR พร้อมเพย์', type: 'qr'),
        PaymentMethod(id: 'pm3', name: 'โอนเงิน', type: 'transfer'),
      ],
      expenseTypes: const <ExpenseType>[ExpenseType(id: 'et1', name: 'แก๊ส')],
      fixedCosts: const <FixedCostItem>[],
      shifts: <ShiftRecord>[
        ShiftRecord(
          id: 'sh1',
          staffId: 'st3',
          openedAt: currentNow
              .subtract(const Duration(hours: 3))
              .toUtc()
              .toIso8601String(),
          floatAmount: 1000,
        ),
      ],
    );
    return MockPosRepository(
      initialState: state,
      sessionStaffId: sessionStaffId,
    );
  }

  /// Loads `assets/mock/*.json` via [AssetBundle] and initializes [PosState]
  /// with clean daily transactions (`seedTransactions: false` by default) while
  /// keeping master catalogs intact.
  static Future<MockPosRepository> loadFromAssets({
    AssetBundle? bundle,
    DateTime? now,
    String? sessionStaffId,
    bool seedTransactions = false,
  }) async {
    final b = bundle ?? rootBundle;
    const keys = <String>[
      'shop',
      'packages',
      'addons',
      'suppliers',
      'ingredients',
      'tables',
      'staff',
      'payments',
      'expense_types',
      'fixed_costs',
    ];
    final jsonByName = <String, String>{};
    for (final k in keys) {
      jsonByName[k] = await b.loadString('assets/mock/$k.json');
    }
    final repo = MockPosRepository.fromJsonStrings(
      jsonByName,
      now: now,
      sessionStaffId: sessionStaffId,
    );
    if (!seedTransactions) {
      repo.update((s) {
        clearDailyTransactionsInState(s, now: now);
        s.shop = s.shop.copyWith(fixedCostDivisor: 'calendar');
      });
    }
    return repo;
  }

  PosState _state;
  String? _sessionStaffId;
  final StreamController<PosState> _controller =
      StreamController<PosState>.broadcast(sync: true);

  @override
  PosState get state => _state;

  @override
  Stream<PosState> get stream => _controller.stream;

  @override
  StaffMember? get currentStaff {
    final id = _sessionStaffId;
    if (id == null) return null;
    for (final member in _state.staff) {
      if (member.id == id && member.active) return member;
    }
    return null;
  }

  @override
  PosState update(void Function(PosState s) mutator) {
    final next = _state.copy();
    mutator(next);
    _state = next.freeze();
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
    return _state;
  }

  @override
  void setSessionStaffId(String? staffId) {
    _sessionStaffId = staffId;
    if (staffId != null) {
      update((s) => s.currentStaffId = staffId);
    } else if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }

  @override
  String exportStateJson() =>
      const JsonEncoder.withIndent('  ').convert(_state.toJson());

  @override
  PosState importStateJson(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final next = PosState.fromJson(decoded).copy().freeze();
    _state = next;
    if (_sessionStaffId != null &&
        !_state.staff.any((x) => x.id == _sessionStaffId && x.active)) {
      _sessionStaffId = _state.staff.where((x) => x.active).firstOrNull?.id;
    }
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
    return _state;
  }

  Future<void> dispose() => _controller.close();
}
