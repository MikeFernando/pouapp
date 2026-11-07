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

  Future<Either<Failure, Unit>> logout();
}
