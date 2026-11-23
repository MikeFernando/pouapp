import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/business_setup.dart';
import '../repositories/business_setup_repository.dart';

class GetBusinessSetup extends UseCase<BusinessSetup, BusinessSetupUserParams> {
  GetBusinessSetup(this.repository);

  final BusinessSetupRepository repository;

  @override
  Future<Either<Failure, BusinessSetup>> call(BusinessSetupUserParams params) {
    return repository.read(params.userId);
  }
}

class SaveBusinessSetup
    extends UseCase<BusinessSetup, SaveBusinessSetupParams> {
  SaveBusinessSetup(this.repository);

  final BusinessSetupRepository repository;

  @override
  Future<Either<Failure, BusinessSetup>> call(SaveBusinessSetupParams params) {
    return repository.save(userId: params.userId, kind: params.kind);
  }
}

class BusinessSetupUserParams extends Equatable {
  const BusinessSetupUserParams(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class SaveBusinessSetupParams extends Equatable {
  const SaveBusinessSetupParams({required this.userId, required this.kind});

  final String userId;
  final BusinessKind kind;

  @override
  List<Object?> get props => [userId, kind];
}
