import 'dart:async';
import 'dart:convert';

import 'package:app/core/data/mock_fallback_state.dart';
import 'package:app/core/data/mock_pos_commands.dart';
import 'package:app/core/data/mock_pos_setup_commands.dart';
import 'package:app/core/data/mock_pos_tax_report.dart';
import 'package:app/core/data/web_storage.dart';
import 'package:app/domain/domain.dart';
import 'package:flutter/services.dart';

const String _kStateStorageKey = 'keptoh_pos_v2_state_v2';
const String _kStaffStorageKey = 'keptoh_pos_v2_staff_v2';

/// In-memory implementation of [PosRepository] backed by `assets/mock/*.json`
/// and `seed()`. Copies [PosState] only on [update], while [state] returns the
/// frozen read-only snapshot in O(1) without copying.
class MockPosRepository
    with MockPosCommands, MockPosSetupCommands, MockPosTaxReport
    implements PosRepository {
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
    final state = buildFallbackState(now ?? DateTime(2026, 11, 4, 12));
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
    final useWebPersistence =
        bundle == null && now == null && !seedTransactions;
    if (useWebPersistence) {
      final savedRaw = readWebLocalStorage(_kStateStorageKey);
      final savedStaff = readWebLocalStorage(_kStaffStorageKey);
      if (savedRaw != null && savedRaw.isNotEmpty) {
        try {
          repo.importStateJson(savedRaw);
        } on Object {
          // Ignore corrupted storage and keep fresh asset state.
        }
      }
      if (savedStaff != null && savedStaff.isNotEmpty) {
        repo.setSessionStaffId(savedStaff);
      }
      repo
        .._persistWeb = true
        .._syncWebStorage();
    }
    return repo;
  }

  static int _billSeq = 0;
  PosState _state;
  String? _sessionStaffId;
  bool _persistWeb = false;
  final StreamController<PosState> _controller =
      StreamController<PosState>.broadcast(sync: true);

  void _syncWebStorage() {
    if (!_persistWeb) return;
    writeWebLocalStorage(_kStateStorageKey, jsonEncode(_state.toJson()));
    if (_sessionStaffId != null && _sessionStaffId!.isNotEmpty) {
      writeWebLocalStorage(_kStaffStorageKey, _sessionStaffId!);
    } else {
      removeWebLocalStorage(_kStaffStorageKey);
    }
  }

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
    _syncWebStorage();
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
    return _state;
  }

  /// Updates the active session staff ID (`null` to sign out).
  void setSessionStaffId(String? staffId) {
    _sessionStaffId = staffId;
    if (staffId != null) {
      update((s) => s.currentStaffId = staffId);
    } else {
      _syncWebStorage();
      if (!_controller.isClosed) {
        _controller.add(_state);
      }
    }
  }

  @override
  Future<List<BillRecord>> billsForDay(String date) async =>
      _state.sales.where((b) => b.date == date).toList();

  @override
  bool get isDemoData => true;

  @override
  bool get canEditSetup => true;

  @override
  bool get canReadCosts => true;

  @override
  Future<PinSignInResult> signInWithPin(String staffId, String pin) async {
    final who = _state.staff.where((x) => x.id == staffId).firstOrNull;
    if (who == null || who.pin != pin) return PinSignInResult.invalid;
    setSessionStaffId(staffId);
    return PinSignInResult.success;
  }

  @override
  Future<void> signOutStaff() async => setSessionStaffId(null);

  @override
  String newBillId(DateTime now) {
    _billSeq = (_billSeq + 1) & 0xFFFFF;
    return 'b${now.millisecondsSinceEpoch.toRadixString(36)}$_billSeq';
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
    _syncWebStorage();
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
    return _state;
  }

  Future<void> dispose() => _controller.close();
}
