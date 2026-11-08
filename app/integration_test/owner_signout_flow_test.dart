import 'package:app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// End-to-end: an owner who signed in on the first screen can sign out and
/// sign in again before pairing, e.g. to switch accounts. Covers ON-10.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('owner signs out on the shop step and signs back in', (
    tester,
  ) async {
    // Arrange
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'e2e-out-$stamp@example.test';
    final password = 'e2e-pass-$stamp';
    await app.main();
    await tapKey(tester, 'choose-owner-btn');
    await typeInto(tester, 'owner-email-input', email);
    await typeInto(tester, 'owner-password-input', password);
    await tapKey(tester, 'owner-signup-btn');
    await waitFor(tester, find.byKey(const ValueKey('shop-name-input')));
    expect(textOf(tester, 'onboarding-owner-email'), contains(email));

    // Act
    await tapKey(tester, 'onboarding-signout-btn');

    // Assert: back on the first screen, signed out.
    await waitFor(tester, find.byKey(const ValueKey('choose-owner-btn')));
    expect(find.byKey(const ValueKey('shop-name-input')), findsNothing);

    // Act: sign in with the same account.
    await tapKey(tester, 'choose-owner-btn');
    await typeInto(tester, 'owner-email-input', email);
    await typeInto(tester, 'owner-password-input', password);
    await tapKey(tester, 'owner-signin-btn');

    // Assert
    await waitFor(tester, find.byKey(const ValueKey('shop-name-input')));
  });
}
