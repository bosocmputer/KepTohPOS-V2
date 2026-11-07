import 'package:app/core/widgets/widgets.dart';
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
  throw TestFailure('Timed out waiting for $finder');
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
