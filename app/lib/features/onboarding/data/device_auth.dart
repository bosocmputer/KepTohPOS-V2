import 'dart:convert';

import 'package:http/http.dart' as http;

/// Saves and restores the device session as a string.
abstract interface class DeviceAuthStorage {
  /// Returns the saved session, or `null` if there is none.
  Future<String?> read();

  /// Saves [value].
  Future<void> write(String value);

  /// Removes the saved session.
  Future<void> clear();
}

/// The POS device's anonymous session, kept away from `GoTrueClient`.
///
/// On the web every `GoTrueClient` for one URL shares its session through a
/// BroadcastChannel that cannot be turned off, so an owner login would replace
/// the device's identity. Calling the Auth API directly avoids that channel.
class DeviceAuth {
  new({
    required this._url,
    required this._anonKey,
    required this._storage,
    http.Client? client,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  static const Duration _refreshMargin = Duration(seconds: 60);

  final String _url;
  final String _anonKey;
  final DeviceAuthStorage _storage;
  final http.Client _client;
  final DateTime Function() _clock;

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  String? _userId;

  /// The device account's user id, or `null` before it signs in.
  String? get userId => _userId;

  /// Restores the saved session. A damaged one is dropped, not fatal.
  Future<void> restore() async {
    final saved = await _storage.read();
    if (saved == null) return;
    try {
      final map = jsonDecode(saved) as Map<String, dynamic>;
      _accessToken = map['access_token'] as String;
      _refreshToken = map['refresh_token'] as String;
      _expiresAt = DateTime.parse(map['expires_at'] as String);
      _userId = map['user_id'] as String;
    } on Object {
      await signOut();
    }
  }

  /// Creates the anonymous device account. [captchaToken] is required by the
  /// server once captcha protection is turned on.
  Future<void> signInAnonymously({String? captchaToken}) => _request(
    Uri.parse('$_url/auth/v1/signup'),
    captchaToken == null
        ? const <String, dynamic>{}
        : <String, dynamic>{
            'gotrue_meta_security': <String, dynamic>{
              'captcha_token': captchaToken,
            },
          },
  );

  /// Returns a usable access token, refreshing it shortly before it expires,
  /// or `null` when signed out so that calls run as the anonymous API role.
  Future<String?> accessToken() async {
    final token = _accessToken;
    if (token == null) return null;
    if (_clock().add(_refreshMargin).isBefore(_expiresAt!)) return token;
    await _request(
      Uri.parse('$_url/auth/v1/token?grant_type=refresh_token'),
      <String, dynamic>{'refresh_token': _refreshToken},
    );
    return _accessToken;
  }

  /// Forgets the session on this device.
  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _userId = null;
    await _storage.clear();
  }

  Future<void> _request(Uri uri, Map<String, dynamic> body) async {
    final res = await _client.post(
      uri,
      headers: <String, String>{
        'apikey': _anonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    // A rejected token will never work again, unlike a temporary outage, so
    // only then does the device go back to pairing.
    if (res.statusCode == 400 || res.statusCode == 401) {
      await signOut();
      throw const DeviceAuthException('device session was rejected');
    }
    if (res.statusCode != 200) {
      throw DeviceAuthException('auth server returned ${res.statusCode}');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    _accessToken = map['access_token'] as String;
    _refreshToken = map['refresh_token'] as String;
    _expiresAt = _clock().add(Duration(seconds: map['expires_in'] as int));
    _userId = (map['user'] as Map<String, dynamic>)['id'] as String;
    await _storage.write(
      jsonEncode(<String, dynamic>{
        'access_token': _accessToken,
        'refresh_token': _refreshToken,
        'expires_at': _expiresAt!.toIso8601String(),
        'user_id': _userId,
      }),
    );
  }
}

/// The device session could not be created or refreshed.
class DeviceAuthException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}
