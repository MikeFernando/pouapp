import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class UpdateUserName implements UseCase<User, UpdateUserNameParams> {
  UpdateUserName(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, User>> call(UpdateUserNameParams params) {
    return repository.updateName(name: params.name);
  }
}

class UpdateUserNameParams extends Equatable {
  const UpdateUserNameParams({required this.name});

  final String name;

  @override
  List<Object?> get props => [name];
}
