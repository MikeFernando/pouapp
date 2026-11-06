import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/freight_ledger.dart';
import '../../domain/failures/freight_failure.dart';
import '../../domain/repositories/freight_repository.dart';
import '../datasources/freight_local_data_source.dart';
import '../models/freight_ledger_codec.dart';

class FreightRepositoryImpl implements FreightRepository {
  FreightRepositoryImpl({required this.localDataSource});

  final FreightLocalDataSource localDataSource;

  @override
  Future<Either<Failure, FreightLedger>> getLedger() async {
    try {
      return Right(_read());
    } on CacheException {
      return const Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, FreightLedger>> apply(FreightChange change) async {
    try {
      final update = updateFreightLedger(_read(), change);
      final ledger = update.ledger;
      if (update.error != null || ledger == null) {
        return Left(
          FreightChangeFailure(
            update.error ?? 'Não foi possível atualizar o frete.',
          ),
        );
      }
      await localDataSource.saveLedger(encodeFreightLedger(ledger));
      return Right(ledger);
    } on CacheException {
      return const Left(CacheFailure());
    }
  }

  FreightLedger _read() {
    final saved = localDataSource.readLedger();
    if (saved == null || saved.isEmpty) return exampleFreightLedger();
    try {
      return decodeFreightLedger(saved);
    } catch (_) {
      return exampleFreightLedger();
    }
  }
}
