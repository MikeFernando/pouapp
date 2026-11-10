import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../error/exceptions.dart';

/// Persists access (prefs) and refresh (secure storage) tokens.
class AuthTokenStore {
  AuthTokenStore({
    required SharedPreferences sharedPreferences,
    FlutterSecureStorage? secureStorage,
  }) : _prefs = sharedPreferences,
       _secure = secureStorage ?? const FlutterSecureStorage();

  static const accessTokenKey = 'AUTH_ACCESS_TOKEN';
  static const refreshTokenKey = 'AUTH_REFRESH_TOKEN';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<String?> readAccessToken() async {
    return _prefs.getString(accessTokenKey);
  }

  Future<String?> readRefreshToken() async {
    try {
      return await _secure.read(key: refreshTokenKey);
    } catch (_) {
      throw CacheException();
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final savedAccess = await _prefs.setString(accessTokenKey, accessToken);
    if (!savedAccess) throw CacheException();
    try {
      await _secure.write(key: refreshTokenKey, value: refreshToken);
    } catch (_) {
      throw CacheException();
    }
  }

  Future<void> clear() async {
    await _prefs.remove(accessTokenKey);
    try {
      await _secure.delete(key: refreshTokenKey);
    } catch (_) {
      throw CacheException();
    }
  }
}
