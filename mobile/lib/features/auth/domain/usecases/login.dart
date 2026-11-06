import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class Login implements UseCase<User, Params> {
  Login(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, User>> call(Params params) {
    return repository.login(email: params.email, password: params.password);
  }
}

class Params extends Equatable {
  const Params({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];

  @override
  bool get stringify => false;

  @override
  String toString() => 'Params(email: $email)';
}
