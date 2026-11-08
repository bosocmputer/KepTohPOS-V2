import 'package:app/core/data/supabase/network_activity.dart';
import 'package:app/core/data/supabase/supabase_pos_repository.dart';
import 'package:app/features/onboarding/data/captcha.dart';
import 'package:app/features/onboarding/data/device_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _kUrl = String.fromEnvironment('SUPABASE_URL');
const String _kAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const String _kDeviceSessionKey = 'keptoh-device-session';
const OAuthProvider _kLineProvider = OAuthProvider('custom:line');

/// A shop the signed-in owner or manager belongs to.
class OwnedShop {
  const new({required this.id, required this.name});

  final String id;
  final String name;
}

/// A POS device of the shop, as the owner sees it in setup.
class ShopDevice {
  const new({
    required this.id,
    required this.code,
    required this.name,
    required this.paired,
    required this.revoked,
    required this.isThisDevice,
  });

  final String id;
  final String code;
  final String name;
  final bool paired;
  final bool revoked;
  final bool isThisDevice;
}

/// [DeviceAuthStorage] backed by the app's persistent local storage.
class _LocalDeviceStorage implements DeviceAuthStorage {
  const new(this._storage);

  final SharedPreferencesLocalStorage _storage;

  @override
  Future<String?> read() => _storage.accessToken();

  @override
  Future<void> write(String value) => _storage.persistSession(value);

  @override
  Future<void> clear() => _storage.removePersistedSession();
}

/// The two logins on one POS: the paired device and, when needed, its owner.
///
/// The device client gets its token from [DeviceAuth], not `GoTrueClient`, so
/// an owner login never replaces the device's identity; see [DeviceAuth].
class DeviceSession {
  new _(this._deviceAuth, this.device, this._activity);

  final DeviceAuth _deviceAuth;
  final NetworkActivity _activity;

  /// `true` while any request to the server is still in flight.
  ValueListenable<bool> get busy => _activity.busy;

  /// The paired device's client. Sales run through this one.
  final SupabaseClient device;

  /// The owner's client, which also receives the LINE login redirect.
  SupabaseClient get owner => Supabase.instance.client;

  /// Whether a real owner account is signed in.
  bool get isOwnerSignedIn {
    final user = owner.auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  /// Initializes Supabase and restores this device's saved session.
  static Future<DeviceSession> start() async {
    final activity = NetworkActivity();
    await Supabase.initialize(
      url: _kUrl,
      publishableKey: _kAnonKey,
      httpClient: activity,
    );
    final storage = SharedPreferencesLocalStorage(
      persistSessionKey: _kDeviceSessionKey,
    );
    await storage.initialize();
    final auth = DeviceAuth(
      url: _kUrl,
      anonKey: _kAnonKey,
      storage: _LocalDeviceStorage(storage),
      client: activity,
    );
    await auth.restore();
    return DeviceSession._(
      auth,
      SupabaseClient(
        _kUrl,
        _kAnonKey,
        accessToken: auth.accessToken,
        httpClient: activity,
      ),
      activity,
    );
  }

  /// Returns the shop this device is paired with, or `null` if it is not.
  Future<String?> pairedShopId() async {
    final uid = _deviceAuth.userId;
    if (uid == null) return null;
    final row = await device
        .from('devices')
        .select('shop_id')
        .eq('auth_user_id', uid)
        .filter('revoked_at', 'is', null)
        .maybeSingle();
    return row?['shop_id'] as String?;
  }

  /// Pairs this device using a one-time code and returns its shop id.
  Future<String> claim(String code) async {
    if (_deviceAuth.userId == null) {
      await _deviceAuth.signInAnonymously(captchaToken: await captchaToken());
    }
    final rows = await device.rpc<List<dynamic>>(
      'claim_device',
      params: <String, dynamic>{'p_pairing_code': code},
    );
    return (rows.first as Map<String, dynamic>)['shop_id'] as String;
  }

  /// Opens the repository for [shopId].
  Future<SupabasePosRepository> openRepository(String shopId) =>
      SupabasePosRepository.open(
        deviceClient: device,
        ownerClient: owner,
        shopId: shopId,
      );

  /// Signs the owner in with email and password.
  Future<void> signInOwner(String email, String password) async {
    await owner.auth.signInWithPassword(
      email: email,
      password: password,
      captchaToken: await captchaToken(),
    );
  }

  /// Creates an owner account. Returns `false` when the project requires the
  /// email to be confirmed before the first sign-in.
  Future<bool> signUpOwner(String email, String password) async {
    final res = await owner.auth.signUp(
      email: email,
      password: password,
      captchaToken: await captchaToken(),
    );
    return res.session != null;
  }

  /// Sends the browser to LINE; the app reloads signed in when it returns.
  Future<void> signInOwnerWithLine() async {
    await owner.auth.signInWithOAuth(_kLineProvider);
  }

  /// Sends the browser to Google; the app reloads signed in when it returns.
  Future<void> signInOwnerWithGoogle() async {
    await owner.auth.signInWithOAuth(OAuthProvider.google);
  }

  /// Lists the shops the signed-in owner can manage.
  Future<List<OwnedShop>> ownerShops() async {
    final rows = await owner.from('shops').select('id, name').order('name');
    return rows
        .map((r) => OwnedShop(id: r['id'] as String, name: r['name'] as String))
        .toList();
  }

  /// Creates a shop with its first owner staff member.
  Future<String> createShop({
    required String shopName,
    required String ownerName,
    required String pin,
  }) async {
    final shopId = await owner.rpc<String>(
      'create_organization_with_shop',
      params: <String, dynamic>{
        'p_org_name': shopName,
        'p_shop_name': shopName,
      },
    );
    final staff = await owner
        .from('staff')
        .insert(<String, dynamic>{
          'shop_id': shopId,
          'name': ownerName,
          'role': 'owner',
        })
        .select('id')
        .single();
    await owner.rpc<void>(
      'set_staff_pin',
      params: <String, dynamic>{'p_staff_id': staff['id'], 'p_pin': pin},
    );
    return shopId;
  }

  /// The shop's devices, oldest first, read with the owner's login.
  Future<List<ShopDevice>> shopDevices(String shopId) async {
    final me = _deviceAuth.userId;
    final rows = await owner
        .from('devices')
        .select('id, code, name, auth_user_id, paired_at, revoked_at')
        .eq('shop_id', shopId)
        .order('code');
    return rows
        .map(
          (r) => ShopDevice(
            id: r['id'] as String,
            code: r['code'] as String,
            name: r['name'] as String,
            paired: r['paired_at'] != null,
            revoked: r['revoked_at'] != null,
            isThisDevice: me != null && r['auth_user_id'] == me,
          ),
        )
        .toList();
  }

  /// Creates a one-time code, valid for 24 hours, that pairs a new device
  /// named [deviceName] with [shopId].
  Future<String> createDeviceCode(String shopId, String deviceName) async {
    final rows = await owner.rpc<List<dynamic>>(
      'create_device_pairing',
      params: <String, dynamic>{'p_shop_id': shopId, 'p_name': deviceName},
    );
    return (rows.first as Map<String, dynamic>)['pairing_code'] as String;
  }

  /// Stops [deviceId] from reading or writing the shop's data.
  Future<void> revokeDevice(String deviceId) async {
    await owner
        .from('devices')
        .update(<String, dynamic>{
          'revoked_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', deviceId);
  }

  /// Registers this device with [shopId] using the owner's permission.
  Future<void> pairThisDevice(String shopId, String deviceName) async {
    final rows = await owner.rpc<List<dynamic>>(
      'create_device_pairing',
      params: <String, dynamic>{'p_shop_id': shopId, 'p_name': deviceName},
    );
    final first = rows.first as Map<String, dynamic>;
    await claim(first['pairing_code'] as String);
  }
}
