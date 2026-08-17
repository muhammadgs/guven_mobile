import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The access/refresh pair, kept in the platform keystore.
///
/// The web client keeps its tokens in `localStorage` under four different key
/// names for historical reasons; there is no such history here, so this stores
/// exactly two values — in the iOS Keychain and Android's
/// `EncryptedSharedPreferences`, not in plain preferences, because an access
/// token is a bearer credential for the whole company's data.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // Android's defaults are already AES-GCM under a Keystore-wrapped
              // key, so only the iOS side needs saying: readable once the
              // device has been unlocked since boot, and never carried to
              // another device by a backup restore.
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const String _accessKey = 'guven_access_token';
  static const String _refreshKey = 'guven_refresh_token';

  final FlutterSecureStorage _storage;

  /// Mirrors what is on disk so the hot path — attaching a header to every
  /// request — does not hit the keystore. Populated by [load].
  String? _access;
  String? _refresh;
  bool _loaded = false;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => _access != null;

  /// Reads both tokens off disk. Safe to call more than once; only the first
  /// call touches the keystore.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    // A keystore read can fail outright on a device whose keys were
    // invalidated (a restored backup, a changed screen lock). That is not an
    // error worth surfacing — it just means there is no session.
    try {
      _access = await _storage.read(key: _accessKey);
      _refresh = await _storage.read(key: _refreshKey);
    } catch (_) {
      _access = null;
      _refresh = null;
    }
  }

  Future<void> save({required String access, String? refresh}) async {
    _access = access;
    if (refresh != null) _refresh = refresh;
    _loaded = true;
    await _storage.write(key: _accessKey, value: access);
    if (refresh != null) {
      await _storage.write(key: _refreshKey, value: refresh);
    }
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// The `exp` claim of a JWT as a local [DateTime], or null when the token is
/// absent, not a JWT, or malformed.
///
/// Used to refresh a token that is about to lapse *before* spending a request
/// finding out, the way the web client's `_ensureValidTokenForApi` does.
DateTime? jwtExpiry(String? token) {
  final Map<String, Object?>? claims = decodeJwtPayload(token);
  final Object? exp = claims?['exp'];
  if (exp is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
}

/// Decodes a JWT's payload without verifying it.
///
/// Verification is the server's job — this is only used to read claims the
/// backend has already vouched for (`exp`, `company_code`) so the app can
/// avoid a round trip. Returns null for anything that is not a three-part JWT.
Map<String, Object?>? decodeJwtPayload(String? token) {
  if (token == null) return null;
  final List<String> parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final String normalised = base64Url.normalize(parts[1]);
    final String json = utf8.decode(base64Url.decode(normalised));
    final Object? decoded = jsonDecode(json);
    return decoded is Map<String, Object?> ? decoded : null;
  } catch (_) {
    return null;
  }
}
