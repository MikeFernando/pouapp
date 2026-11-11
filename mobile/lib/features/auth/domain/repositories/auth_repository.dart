import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  });

  /// Creates an account and starts its session.
  Future<Either<Failure, User>> register({
    required String name,
    required String email,
    required String password,
  });

  Future<Either<Failure, User?>> getCurrentUser();

  /// Updates the authenticated user's display name.
  Future<Either<Failure, User>> updateName({required String name});

  Future<Either<Failure, Unit>> logout();
}
