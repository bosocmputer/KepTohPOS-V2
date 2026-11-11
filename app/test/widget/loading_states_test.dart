import 'dart:async';

import 'package:app/core/data/mock_pos_repository.dart';
import 'package:app/core/data/supabase/network_activity.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/widgets.dart';
import 'package:app/domain/domain.dart';
import 'package:app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app/features/onboarding/presentation/onboarding_shell.dart';
import 'package:app/features/onboarding/presentation/owner_pin_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

/// Holds the PIN check open until the test completes [reply].
class _SlowPinRepository extends MockPosRepository {
  new({required super.initialState});

  final Completer<PinSignInResult> reply = Completer<PinSignInResult>();

  @override
  Future<PinSignInResult> signInWithPin(String staffId, String pin) =>
      reply.future;
}

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.build(brightness: Brightness.light),
  builder: (context, page) => page!,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('while busy, taps are blocked and a progress bar shows', (
    tester,
  ) async {
    // Arrange
    final busy = ValueNotifier<bool>(false);
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        BusyOverlay(
          busy: busy,
          child: Btn(label: 'ชำระเงิน', onPressed: () => taps++),
        ),
      ),
    );

    // Act
    busy.value = true;
    await tester.pump();
    await tester.tap(find.text('ชำระเงิน'), warnIfMissed: false);
    final barsWhileBusy = find
        .byType(LinearProgressIndicator)
        .evaluate()
        .length;
    final loadersWhileBusy = find.byType(WalkingOrangeLoader).evaluate().length;
    busy.value = false;
    await tester.pump();
    await tester.tap(find.text('ชำระเงิน'));

    // Assert
    expect(barsWhileBusy, 1);
    expect(loadersWhileBusy, 1);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(WalkingOrangeLoader), findsNothing);
    expect(taps, 1);
  });

  test(
    'NetworkActivity.instance.hold keeps busy true across sequential gaps',
    () async {
      // Arrange
      final activity = NetworkActivity();
      addTearDown(activity.close);
      final transitions = <bool>[];
      activity.busy.addListener(() => transitions.add(activity.busy.value));

      // Act
      final result = await NetworkActivity.instance.hold(() async {
        activity.begin();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        activity.end();
        // Gap between sequential async calls (e.g. staffRpc -> reload)
        await Future<void>.delayed(const Duration(milliseconds: 10));
        activity.begin();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        activity.end();
        return 'ok';
      });

      // Assert
      expect(result, 'ok');
      expect(activity.busy.value, isFalse);
      expect(transitions, <bool>[true, false]);
    },
  );

  testWidgets('PIN setup shows progress while the shop is created', (
    tester,
  ) async {
    // Arrange & Act
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 360,
          child: OwnerPinSetup(busy: true, onConfirmed: (_) {}, onBack: () {}),
        ),
      ),
    );

    // Assert
    expect(find.text('กำลังสร้างร้าน…'), findsOneWidget);
  });

  test('AuthCubit marks a slow PIN check until the reply', () async {
    // Arrange
    final repo = _SlowPinRepository(
      initialState: MockPosRepository.createFallback().state,
    );
    final cubit = AuthCubit(repo, now: DateTime(2026, 11, 4, 12));
    addTearDown(cubit.close);

    // Act
    final submitted = cubit.submitPin('9999');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final whileWaiting = cubit.state.checking;
    repo.reply.complete(PinSignInResult.invalid);
    await submitted;

    // Assert
    expect(whileWaiting, isTrue);
    expect(cubit.state.checking, isFalse);
    expect(cubit.state.error, isNotEmpty);
  });

  testWidgets('OnboardingLoadingCard keeps Lottie and subtitle while busy', (
    tester,
  ) async {
    // Arrange
    final activity = NetworkActivity();
    addTearDown(activity.close);
    NetworkActivity.instance.begin();

    // Act
    await tester.pumpWidget(
      _wrap(
        const OnboardingLoadingCard(
          title: 'เก็บโต๊ะ POS',
          subtitle: 'กำลังจัดเตรียมข้อมูลร้าน...',
        ),
      ),
    );
    await tester.pump();

    // Assert
    expect(NetworkActivity.instance.busy.value, isTrue);
    expect(find.byKey(const ValueKey('walking-orange-loader')), findsOneWidget);
    expect(find.byType(LottieBuilder), findsOneWidget);
    expect(find.text('เก็บโต๊ะ POS'), findsOneWidget);
    expect(find.text('กำลังจัดเตรียมข้อมูลร้าน...'), findsOneWidget);
  });
}
