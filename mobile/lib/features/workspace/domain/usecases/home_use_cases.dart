import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/home_remote_data_source.dart';
import '../entities/home_board.dart';

class GetHomeBoard implements UseCase<HomeBoard, String?> {
  GetHomeBoard(this.remote);

  final HomeRemoteDataSource remote;

  @override
  Future<Either<Failure, HomeBoard>> call(String? date) async {
    try {
      return Right(await remote.getHome(date: date));
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException {
      return const Left(ServerFailure());
    }
  }
}

class CreateHomeNote {
  CreateHomeNote(this.remote);

  final HomeRemoteDataSource remote;

  Future<Either<Failure, Unit>> call({
    required String customerId,
    required String dueOn,
    required int totalCents,
  }) async {
    try {
      await remote.createNote(
        customerId: customerId,
        dueOn: dueOn,
        totalCents: totalCents,
      );
      return const Right(unit);
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException {
      return const Left(ServerFailure());
    }
  }
}
