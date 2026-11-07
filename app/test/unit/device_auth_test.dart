import 'dart:convert';

import 'package:app/features/onboarding/data/device_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemoryStorage implements DeviceAuthStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String next) async => value = next;

  @override
  Future<void> clear() async => value = null;
}

http.Response _tokenResponse(String access, {int expiresIn = 3600}) =>
    http.Response(
      jsonEncode(<String, dynamic>{
        'access_token': access,
        'refresh_token': 'refresh-$access',
        'expires_in': expiresIn,
        'user': <String, dynamic>{'id': 'device-user'},
      }),
      200,
    );

void main() {
  late _MemoryStorage storage;
  late DateTime now;
  late List<http.Request> requests;

  DeviceAuth build(http.Response Function(http.Request) handler) => DeviceAuth(
    url: 'https://example.test',
    anonKey: 'anon-key',
    storage: storage,
    clock: () => now,
    client: MockClient((request) async {
      requests.add(request);
      return handler(request);
    }),
  );

  setUp(() {
    storage = _MemoryStorage();
    now = DateTime.utc(2026, 11, 7, 12);
    requests = <http.Request>[];
  });

  test('signing in saves the session and exposes the device user', () async {
    // Arrange
    final auth = build((_) => _tokenResponse('a1'));

    // Act
    await auth.signInAnonymously();

    // Assert
    expect(auth.userId, 'device-user');
    expect(await auth.accessToken(), 'a1');
    expect(requests.single.url.path, '/auth/v1/signup');
    expect(requests.single.headers['apikey'], 'anon-key');
    expect(storage.value, contains('refresh-a1'));
  });

  test('a restored session keeps working without calling the server', () async {
    // Arrange
    await build((_) => _tokenResponse('a1')).signInAnonymously();
    requests.clear();
    final restored = build((_) => _tokenResponse('unused'));

    // Act
    await restored.restore();

    // Assert
    expect(restored.userId, 'device-user');
    expect(await restored.accessToken(), 'a1');
    expect(requests, isEmpty);
  });

  test('refreshes shortly before expiry and keeps the new token', () async {
    // Arrange
    var issued = 0;
    final auth = build((_) => _tokenResponse('a${++issued}'));
    await auth.signInAnonymously();

    // Act
    now = now.add(const Duration(minutes: 59, seconds: 30));
    final token = await auth.accessToken();

    // Assert
    expect(token, 'a2');
    expect(requests.last.url.queryParameters['grant_type'], 'refresh_token');
    expect(
      (jsonDecode(requests.last.body) as Map<String, dynamic>)['refresh_token'],
      'refresh-a1',
    );
    expect(storage.value, contains('refresh-a2'));
  });

  test(
    'a rejected refresh token signs out so the device can re-pair',
    () async {
      // Arrange
      var calls = 0;
      final auth = build(
        (_) => ++calls == 1
            ? _tokenResponse('a1')
            : http.Response('{"error":"invalid_grant"}', 400),
      );
      await auth.signInAnonymously();
      now = now.add(const Duration(hours: 2));

      // Act & Assert
      await expectLater(
        auth.accessToken(),
        throwsA(isA<DeviceAuthException>()),
      );
      expect(auth.userId, isNull);
      expect(storage.value, isNull);
      expect(await auth.accessToken(), isNull);
    },
  );

  test('a server outage keeps the session for the next attempt', () async {
    // Arrange
    var calls = 0;
    final auth = build(
      (_) => ++calls == 1 ? _tokenResponse('a1') : http.Response('down', 503),
    );
    await auth.signInAnonymously();
    now = now.add(const Duration(hours: 2));

    // Act & Assert
    await expectLater(auth.accessToken(), throwsA(isA<DeviceAuthException>()));
    expect(auth.userId, 'device-user');
    expect(storage.value, isNotNull);
  });

  test('damaged saved data is dropped instead of crashing startup', () async {
    // Arrange
    storage.value = 'not json';
    final auth = build((_) => _tokenResponse('unused'));

    // Act
    await auth.restore();

    // Assert
    expect(auth.userId, isNull);
    expect(storage.value, isNull);
  });

  test('signed out returns no token', () async {
    // Arrange
    final auth = build((_) => _tokenResponse('unused'));

    // Assert
    expect(await auth.accessToken(), isNull);
    expect(requests, isEmpty);
  });
}
