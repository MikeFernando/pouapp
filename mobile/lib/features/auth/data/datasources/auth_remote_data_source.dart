import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exceptions.dart';
import '../exceptions/auth_exceptions.dart';
import '../models/user_model.dart';
import '../simulated_auth_policy.dart';

abstract class AuthRemoteDataSource {
  /// Authenticates [email] and [password].
  ///
  /// Throws [InvalidCredentialsException] when the credentials are rejected.
  /// Throws [SimulatedAuthDisabledException] when simulated auth is off.
  Future<UserModel> login({required String email, required String password});

  /// Creates an account that [login] can authenticate later.
  ///
  /// Throws [EmailAlreadyRegisteredException] when [email] is already in use.
  /// Throws [SimulatedAuthDisabledException] when simulated auth is off.
  /// Throws [CacheException] when the account cannot be stored.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  });

  /// Ends the remote session. The simulated source has no server session.
  Future<void> logout();
}

/// Development-only stand-in for a future REST data source.
///
/// [simulatedAuthEnabled] is compiled from the Flutter mode. Passing
/// `enabled: true` cannot turn the simulation on in profile or release.
///
/// Accounts created at runtime are stored only while this simulation is on.
/// The session cache itself still does not keep a password.
class SimulatedAuthRemoteDataSource implements AuthRemoteDataSource {
  SimulatedAuthRemoteDataSource({
    this.delay = const Duration(milliseconds: 300),
    bool? enabled,
    this._sharedPreferences,
  }) : enabled = enabled ?? simulatedAuthEnabled;

  final Duration delay;
  final bool enabled;
  final SharedPreferences? _sharedPreferences;
  final List<_DevelopmentAccount> _memoryAccounts = [];

  static const _builtinAccounts = <_DevelopmentAccount>[
    _DevelopmentAccount(
      email: 'mike@gmail.com',
      password: 'mike@123',
      user: UserModel(
        id: 'dev-user-mike',
        name: 'Mike',
        email: 'mike@gmail.com',
      ),
    ),
    _DevelopmentAccount(
      email: 'edipo@pouapp.com',
      password: '123456',
      user: UserModel(
        id: 'dev-user-edipo',
        name: 'Edipo Silva',
        email: 'edipo@pouapp.com',
      ),
    ),
  ];

  bool get _allowsAuth => simulatedAuthEnabled && enabled;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    if (!_allowsAuth) {
      throw SimulatedAuthDisabledException();
    }

    await Future<void>.delayed(delay);
    final normalizedEmail = email.trim().toLowerCase();
    for (final account in _builtinAccounts) {
      if (account.email == normalizedEmail && account.password == password) {
        return account.user;
      }
    }
    for (final account in _readStored()) {
      if (account.email == normalizedEmail && account.password == password) {
        return account.user;
      }
    }
    throw InvalidCredentialsException();
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!_allowsAuth) {
      throw SimulatedAuthDisabledException();
    }

    await Future<void>.delayed(delay);
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = name.trim();
    final stored = _readStored();
    final taken = [
      ..._builtinAccounts,
      ...stored,
    ].any((account) => account.email == normalizedEmail);
    if (taken) {
      throw EmailAlreadyRegisteredException();
    }

    final user = UserModel(
      id: 'user-${normalizedEmail.replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
      name: normalizedName,
      email: normalizedEmail,
    );
    await _writeStored([
      ...stored,
      _DevelopmentAccount(
        email: normalizedEmail,
        password: password,
        user: user,
      ),
    ]);
    return user;
  }

  @override
  Future<void> logout() async {}

  List<_DevelopmentAccount> _readStored() {
    if (_sharedPreferences == null) {
      return List<_DevelopmentAccount>.of(_memoryAccounts);
    }

    final raw = _sharedPreferences.getString(simulatedAccountsKey);
    if (raw == null) return const [];

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) throw const FormatException();
      return decoded.map((item) {
        if (item is! Map) throw const FormatException();
        final map = Map<String, dynamic>.from(item);
        final email = map['email'] as String;
        return _DevelopmentAccount(
          email: email,
          password: map['password'] as String,
          user: UserModel(
            id: map['id'] as String,
            name: map['name'] as String,
            email: email,
          ),
        );
      }).toList();
    } catch (_) {
      throw CacheException();
    }
  }

  Future<void> _writeStored(List<_DevelopmentAccount> accounts) async {
    if (_sharedPreferences == null) {
      _memoryAccounts
        ..clear()
        ..addAll(accounts);
      return;
    }

    final saved = await _sharedPreferences.setString(
      simulatedAccountsKey,
      json.encode([
        for (final account in accounts)
          {
            'id': account.user.id,
            'name': account.user.name,
            'email': account.email,
            'password': account.password,
          },
      ]),
    );
    if (!saved) throw CacheException();
  }
}

const simulatedAccountsKey = 'SIMULATED_AUTH_ACCOUNTS';

class _DevelopmentAccount {
  const _DevelopmentAccount({
    required this.email,
    required this.password,
    required this.user,
  });

  final String email;
  final String password;
  final UserModel user;
}
