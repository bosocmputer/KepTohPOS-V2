import 'package:app/core/widgets/widgets.dart';
import 'package:app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The local Supabase stack the app under test talks to.
const String kE2eUrl = String.fromEnvironment('SUPABASE_URL');
const String kE2eAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Pumps until [finder] matches, without waiting for animations to stop:
/// table countdowns and the busy bar keep the app from ever settling.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure(
    'Timed out waiting for $finder\nOn screen: ${_screenText()}',
  );
}

/// Pumps until [finder] no longer matches.
Future<void> waitGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder to disappear');
}

/// Waits until no request is in flight, so the busy overlay is not blocking
/// taps. On-screen totals can update before the server has answered.
Future<void> waitForServer(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 150));
  await waitGone(tester, find.byKey(const ValueKey('busy-overlay')));
}

/// Waits for [finder], then taps its first match.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 200));
}

/// Taps a widget by its `ValueKey<String>`.
Future<void> tapKey(WidgetTester tester, String key) =>
    tapOn(tester, find.byKey(ValueKey(key)));

/// Types [text] into the text field under the `ValueKey<String>` [key].
Future<void> typeInto(WidgetTester tester, String key, String text) async {
  final field = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(EditableText),
  );
  await waitFor(tester, field);
  await tester.enterText(field.first, text);
  await tester.pump(const Duration(milliseconds: 200));
}

/// Enters [digits] on the first visible [NumPad].
Future<void> typeOnPad(WidgetTester tester, String digits) async {
  final pad = find.byType(NumPad);
  await waitFor(tester, pad);
  for (final d in digits.split('')) {
    await tester.tap(find.descendant(of: pad.first, matching: find.text(d)));
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Text shown by the widget under [key], for checking amounts.
String textOf(WidgetTester tester, String key) {
  final texts = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(Text),
    matchRoot: true,
  );
  return texts.evaluate().map((e) => (e.widget as Text).data ?? '').join(' ');
}

/// A test-only client signed in as the shop owner, used to set up the catalog
/// directly so each flow test starts from known data.
Future<SupabaseClient> ownerClient(String email, String password) async {
  final client = SupabaseClient(kE2eUrl, kE2eAnonKey);
  await client.auth.signInWithPassword(email: email, password: password);
  return client;
}

/// Types [text] into the form field labelled [label].
Future<void> typeIntoField(
  WidgetTester tester,
  String label,
  String text,
) async {
  final field = find.descendant(
    of: find.byWidgetPredicate((w) => w is Field && w.label == label),
    matching: find.byType(EditableText),
  );
  await waitFor(tester, field);
  await tester.enterText(field.first, text);
  await tester.pump(const Duration(milliseconds: 200));
}

/// A freshly signed-up owner and the shop they created.
class E2eShop {
  const new({
    required this.email,
    required this.password,
    required this.shopName,
  });

  final String email;
  final String password;
  final String shopName;
}

/// Starts the app, signs up a new owner and creates a shop with PIN 1234,
/// ending on the staff PIN screen.
Future<E2eShop> createShop(WidgetTester tester) async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final shop = E2eShop(
    email: 'e2e-$stamp@example.test',
    password: 'e2e-pass-$stamp',
    shopName: 'ร้าน E2E $stamp',
  );
  await app.main();
  await tapKey(tester, 'choose-owner-btn');
  await typeInto(tester, 'owner-email-input', shop.email);
  await typeInto(tester, 'owner-password-input', shop.password);
  await tapKey(tester, 'owner-signup-btn');
  await typeInto(tester, 'shop-name-input', shop.shopName);
  await typeInto(tester, 'owner-name-input', 'เจ้าของ E2E');
  await tapKey(tester, 'shop-next-btn');
  await typeOnPad(tester, '1234');
  await waitFor(tester, find.text('ยืนยัน PIN อีกครั้ง'));
  await typeOnPad(tester, '1234');
  await waitFor(tester, find.text('เข้าสู่ระบบ'));
  return shop;
}

/// Enters [pin] on the login screen and opens the shift if asked to.
Future<void> signInAndOpenShift(WidgetTester tester, String pin) async {
  await typeOnPad(tester, pin);
  await waitForServer(tester);
  final openShift = find.byKey(const ValueKey('open-shift-submit-btn'));
  await waitFor(tester, find.textContaining('กะ'));
  if (openShift.evaluate().isNotEmpty) {
    await tapKey(tester, 'open-shift-submit-btn');
    await waitForServer(tester);
  }
  await waitFor(tester, find.text('กะเปิด'));
}

/// The shop's id, read with the owner's own login.
Future<String> shopIdOf(SupabaseClient owner, E2eShop shop) async {
  final row = await owner
      .from('shops')
      .select('id')
      .eq('name', shop.shopName)
      .single();
  return row['id'] as String;
}

/// Visible text, to show where a timed-out test was stuck.
String _screenText() => find
    .byType(RichText)
    .evaluate()
    .map((e) => (e.widget as RichText).text.toPlainText())
    .where((t) => t.trim().isNotEmpty)
    .take(80)
    .join(' | ');
