import '../exceptions/auth_exceptions.dart';
import '../models/user_model.dart';
import '../simulated_auth_policy.dart';

abstract class AuthRemoteDataSource {
  /// Authenticates [email] and [password].
  ///
  /// Throws [InvalidCredentialsException] when the credentials are rejected.
  /// Throws [SimulatedAuthDisabledException] when simulated auth is off.
  Future<UserModel> login({required String email, required String password});

  /// Ends the remote session. The simulated source has no server session.
  Future<void> logout();
}

/// Development-only stand-in for a future REST data source.
///
/// [simulatedAuthEnabled] is compiled from the Flutter mode. Passing
/// `enabled: true` cannot turn the simulation on in profile or release.
class SimulatedAuthRemoteDataSource implements AuthRemoteDataSource {
  SimulatedAuthRemoteDataSource({
    this.delay = const Duration(milliseconds: 300),
    bool? enabled,
  }) : enabled = enabled ?? simulatedAuthEnabled;

  final Duration delay;
  final bool enabled;

  static const _accounts = <_DevelopmentAccount>[
    _DevelopmentAccount(
      email: 'ana.souza@pouapp.dev',
      password: 'senha-dev',
      user: UserModel(
        id: 'dev-user-ana',
        name: 'Ana Souza',
        email: 'ana.souza@pouapp.dev',
      ),
    ),
  ];

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    if (!simulatedAuthEnabled || !enabled) {
      throw SimulatedAuthDisabledException();
    }

    await Future<void>.delayed(delay);
    final normalizedEmail = email.trim().toLowerCase();
    for (final account in _accounts) {
      if (account.email == normalizedEmail && account.password == password) {
        return account.user;
      }
    }
    throw InvalidCredentialsException();
  }

  @override
  Future<void> logout() async {}
}

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
