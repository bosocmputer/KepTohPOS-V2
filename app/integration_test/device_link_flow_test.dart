import 'dart:convert';

import 'package:app/features/onboarding/data/device_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'support.dart';

/// Keeps the phone's session in memory only.
class _MemoryStorage implements DeviceAuthStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String next) async => value = next;

  @override
  Future<void> clear() async => value = null;
}

/// End-to-end: the owner makes a one-time link for a second device in setup,
/// another device joins with it, and the owner then revokes that device.
/// Covers ON-05 and ON-08.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The phone talks to the Auth and REST APIs directly: a second
  // `SupabaseClient` in this page would broadcast its sign-in to the app's
  // owner session, which a real phone (another browser) never does.
  final phone = DeviceAuth(
    url: kE2eUrl,
    anonKey: kE2eAnonKey,
    storage: _MemoryStorage(),
  );
  Future<http.Response> phoneCall(String path, [Object? body]) async {
    final headers = <String, String>{
      'apikey': kE2eAnonKey,
      'Authorization': 'Bearer ${await phone.accessToken()}',
      'Content-Type': 'application/json',
    };
    final uri = Uri.parse('$kE2eUrl/rest/v1/$path');
    return body == null
        ? await http.get(uri, headers: headers)
        : await http.post(uri, headers: headers, body: jsonEncode(body));
  }

  testWidgets('owner links a second device and later revokes it', (
    tester,
  ) async {
    // Arrange
    final e2e = await createShop(tester);
    await signInAndOpenShift(tester, '1234');
    await tapKey(tester, 'shell-menu-btn');
    await tapKey(tester, 'drawer-nav-setup');
    await tapKey(tester, 'setup-tab-devices');

    // Act: make a link for the manager's phone.
    await typeInto(tester, 'device-name-input', 'มือถือผู้จัดการ');
    await tapKey(tester, 'device-create-btn');
    await waitForServer(tester);
    await waitFor(tester, find.byKey(const ValueKey('device-link-text')));
    final link = Uri.parse(
      tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('device-link-text')),
          )
          .data!,
    );

    // Assert: the link carries the code and asks LINE for the real browser.
    expect(link.queryParameters['openExternalBrowser'], '1');
    final code = link.queryParameters['pair']!;
    await waitFor(tester, find.text('รอเปิดลิงก์'));

    // Act: the phone opens the link, i.e. claims the code as a new device.
    await phone.signInAnonymously();
    final claimed = await phoneCall('rpc/claim_device', <String, dynamic>{
      'p_pairing_code': code,
    });
    expect(claimed.statusCode, 200, reason: claimed.body);
    final deviceCode =
        ((jsonDecode(claimed.body) as List<dynamic>).single
                as Map<String, dynamic>)['device_code']
            as String;

    final before = await phoneCall('shops?select=id');
    expect(jsonDecode(before.body), hasLength(1));

    // Act: the owner revokes it from the list.
    await tapKey(tester, 'setup-tab-staff');
    await tapKey(tester, 'setup-tab-devices');
    await waitFor(tester, find.text('ใช้งานอยู่'));
    await tapKey(tester, 'device-revoke-$deviceCode');
    await tapKey(tester, 'device-revoke-confirm-btn');
    await waitForServer(tester);

    // Assert: the server marks it revoked and the phone loses access.
    await waitFor(tester, find.text('ยกเลิกแล้ว'));
    final owner = await ownerClient(e2e.email, e2e.password);
    final row = await owner
        .from('devices')
        .select('revoked_at')
        .eq('shop_id', await shopIdOf(owner, e2e))
        .eq('code', deviceCode)
        .single();
    expect(row['revoked_at'], isNotNull);
    final after = await phoneCall('shops?select=id');
    expect(jsonDecode(after.body), isEmpty);
  });
}
