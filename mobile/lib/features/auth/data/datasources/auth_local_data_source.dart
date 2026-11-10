import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  /// Returns the stored session, or null when there is none.
  ///
  /// Throws [CacheException] when the stored value cannot be read.
  Future<UserModel?> getCachedUser();

  /// Persists [user]. Does not store a password.
  ///
  /// Throws [CacheException] when the value cannot be written.
  Future<void> cacheUser(UserModel user);

  Future<void> clear();
}

const cachedAuthUserKey = 'CACHED_AUTH_USER';

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  @override
  Future<UserModel?> getCachedUser() async {
    final jsonString = sharedPreferences.getString(cachedAuthUserKey);
    if (jsonString == null) return null;

    try {
      final decoded = json.decode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return UserModel.fromJson(decoded);
    } catch (_) {
      throw CacheException();
    }
  }

  @override
  Future<void> cacheUser(UserModel user) async {
    final saved = await sharedPreferences.setString(
      cachedAuthUserKey,
      json.encode(user.toJson()),
    );
    if (!saved) throw CacheException();
  }

  @override
  Future<void> clear() async {
    final removed = await sharedPreferences.remove(cachedAuthUserKey);
    if (!removed && sharedPreferences.containsKey(cachedAuthUserKey)) {
      throw CacheException();
    }
  }
}
