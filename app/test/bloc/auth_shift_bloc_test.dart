import 'dart:io';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

MockPosRepository _createSeededRepo({
  DateTime? now,
  bool closeActiveShift = false,
}) {
  final fixedNow = now ?? DateTime(2026, 11, 4, 12);
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
  final jsonByName = <String, String>{
    for (final k in keys) k: File('assets/mock/$k.json').readAsStringSync(),
  };
  final repo = MockPosRepository.fromJsonStrings(jsonByName, now: fixedNow);
  if (closeActiveShift) {
    repo.update((s) {
      closeShift(s, staffId: 'st3', counted: 544600, now: fixedNow);
    });
  }
  return repo;
}

/// Repository whose PIN check always reports a lockout.
class _LockedPinRepository extends Fake implements PosRepository {
  new(this._inner);

  final PosRepository _inner;

  @override
  PosState get state => _inner.state;

  @override
  Stream<PosState> get stream => _inner.stream;

  @override
  StaffMember? get currentStaff => _inner.currentStaff;

  @override
  bool get canReadCosts => _inner.canReadCosts;

  @override
  bool get isDemoData => _inner.isDemoData;

  @override
  Future<PinSignInResult> signInWithPin(String staffId, String pin) async =>
      PinSignInResult.locked;
}

void main() {
  group('PosRepository immutability & PosState.copy()', () {
    test('state getter returns read-only snapshot without copying on read', () {
      final repo = _createSeededRepo(closeActiveShift: true);
      final before = repo.state;
      expect(identical(before, repo.state), isTrue);
      expect(before.shifts.clear, throwsUnsupportedError);
      expect(before.openTables.clear, throwsUnsupportedError);
      expect(openShiftOf(before), isNull);
      final shiftsBefore = before.shifts.length;

      final after = repo.update((s) {
        openShift(s, staffId: 'st1', floatAmount: 120000);
      });

      expect(identical(before, after), isFalse);
      expect(identical(after, repo.state), isTrue);
      expect(before.shifts.length, shiftsBefore);
      expect(openShiftOf(before), isNull);
      expect(after.shifts.length, shiftsBefore + 1);
      expect(openShiftOf(after)?.floatAmount, 120000);
    });
  });

  group('AuthCubit bloc_test (PIN validation, ledger hero, logout)', () {
    test('initial state computes lastClosedDay & netProfit matching JS', () {
      final fixedNow = DateTime(2026, 11, 4, 12);
      final repo = _createSeededRepo(now: fixedNow);
      final cubit = AuthCubit(repo, now: fixedNow);
      addTearDown(cubit.close);

      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.selectedStaffId, 'st1');
      expect(cubit.state.lastClosedDay?.date, '2026-11-03');
      expect(cubit.state.lastClosedDay?.net, 2844700);
      expect(
        cubit.state.heroProfitValue / 100,
        closeTo(15298.971781485305, 1e-9),
      );

      repo.update((s) => s.shop = s.shop.copyWith(showNetProfit: false));
      expect(
        cubit.state.heroProfitValue / 100,
        closeTo(16935.63844815197, 1e-9),
      );
    });

    blocTest<AuthCubit, AuthState>(
      'wrong PIN clears input and emits error message',
      build: () =>
          AuthCubit(_createSeededRepo(), now: DateTime(2026, 11, 4, 12)),
      act: (cubit) async {
        cubit.setPin('9999');
        await cubit.submitPin();
      },
      verify: (cubit) {
        expect(cubit.state.isAuthenticated, isFalse);
        expect(cubit.state.pin, '');
        expect(cubit.state.error, 'PIN ไม่ถูกต้อง ลองใหม่อีกครั้ง');
      },
    );

    test(
      'locked PIN result shows a retry message and stays signed out',
      () async {
        // Arrange
        final cubit = AuthCubit(
          _LockedPinRepository(_createSeededRepo()),
          now: DateTime(2026, 11, 4, 12),
        )..setPin('1111');

        // Act
        final ok = await cubit.submitPin();

        // Assert
        expect(ok, isFalse);
        expect(cubit.state.isAuthenticated, isFalse);
        expect(cubit.state.pin, '');
        expect(cubit.state.error, 'ใส่ PIN ผิดหลายครั้ง กรุณาลองใหม่ภายหลัง');
        await cubit.close();
      },
    );

    blocTest<AuthCubit, AuthState>(
      'correct PIN logs in staff, sets shouldPromptOpenShift, '
      'and logout clears session',
      build: () => AuthCubit(
        _createSeededRepo(closeActiveShift: true),
        now: DateTime(2026, 11, 4, 12),
      ),
      act: (cubit) async {
        cubit
          ..selectStaff('st3')
          ..setPin('1111');
        await cubit.submitPin();
        await cubit.logout();
      },
      expect: () => [
        isA<AuthState>().having(
          (s) => s.selectedStaffId,
          'selectedStaffId',
          'st3',
        ),
        isA<AuthState>().having((s) => s.pin, 'pin', '1111'),
        isA<AuthState>()
            .having((s) => s.currentStaff?.id, 'currentStaff', 'st3')
            .having((s) => s.shouldPromptOpenShift, 'promptShift', isTrue),
        isA<AuthState>()
            .having((s) => s.currentStaff, 'loggedOut', isNull)
            .having((s) => s.shouldPromptOpenShift, 'promptShift', isFalse),
      ],
    );
  });

  group('ShiftBloc bloc_test (JS parity for expected cash, close & open)', () {
    test('initial seeded open shift stats match JS stats(openShiftOf(s))', () {
      final repo = _createSeededRepo();
      final bloc = ShiftBloc(repo);
      addTearDown(bloc.close);

      final st = bloc.state.activeStats!;
      expect(bloc.state.isShiftOpen, isTrue);
      expect(bloc.state.activeShift?.floatAmount, 100000);
      expect(st.bills, 9);
      expect(st.cash, 444600);
      expect(st.qr, 438400);
      expect(st.transfer, 0);
      expect(st.expected, 544600);
    });

    blocTest<ShiftBloc, ShiftState>(
      'counts cash, computes variance, closes shift, and opens new shift',
      build: () => ShiftBloc(_createSeededRepo()),
      act: (bloc) {
        bloc
          ..add(const ShiftCountedInputChanged('5406'))
          ..add(ShiftClosed(staffId: 'st3', now: DateTime(2026, 11, 4, 22)))
          ..add(const ShiftFloatInputChanged('1500'))
          ..add(
            ShiftOpened(staffId: 'st1', now: DateTime(2026, 11, 4, 22, 30)),
          );
      },
      verify: (bloc) {
        expect(bloc.state.isShiftOpen, isTrue);
        expect(bloc.state.activeShift?.staffId, 'st1');
        expect(bloc.state.activeShift?.floatAmount, 150000);
        expect(bloc.state.activeStats?.expected, 150000);
        expect(bloc.state.activeStats?.bills, 0);
        expect(bloc.state.toastMessage, 'เปิดกะแล้ว');
        expect(bloc.state.history.first.counted, 540600);
        expect(bloc.state.history.first.closedBy, 'st3');
      },
    );
  });
}
