import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/customer_note.dart';
import '../../domain/repositories/customer_note_repository.dart';
import '../datasources/customer_note_local_data_source.dart';
import '../exceptions/note_exceptions.dart';

class CustomerNoteRepositoryImpl implements CustomerNoteRepository {
  CustomerNoteRepositoryImpl({required this.localDataSource});

  final CustomerNoteLocalDataSource localDataSource;

  @override
  Future<Either<Failure, CustomerNote>> activeDraft(String customerId) {
    return _guard(() => localDataSource.activeDraft(customerId));
  }

  @override
  Future<Either<Failure, CustomerNote>> openNote(String customerId) {
    return _guard(() => localDataSource.openNote(customerId));
  }

  @override
  Future<Either<Failure, CustomerNote?>> currentNote(String customerId) {
    return _guard(() => localDataSource.currentNote(customerId));
  }

  @override
  Future<Either<Failure, CustomerNote>> note(String id) {
    return _guard(() => localDataSource.note(id));
  }

  @override
  Future<Either<Failure, CustomerNote>> saveLines({
    required String noteId,
    required List<NoteLineDraft> lines,
  }) {
    return _guard(
      () => localDataSource.saveLines(noteId: noteId, lines: lines),
    );
  }

  @override
  Future<Either<Failure, CustomerNote>> setDueOn({
    required String noteId,
    required DateTime? dueOn,
  }) {
    return _guard(() => localDataSource.setDueOn(noteId: noteId, dueOn: dueOn));
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on NoteRuleException {
      return const Left(CacheFailure());
    } on NoteNotFoundException {
      return const Left(CacheFailure());
    } on CacheException {
      return const Left(CacheFailure());
    } on DatabaseException {
      return const Left(CacheFailure());
    }
  }
}
