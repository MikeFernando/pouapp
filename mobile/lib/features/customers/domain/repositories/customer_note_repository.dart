import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/customer_note.dart';

abstract class CustomerNoteRepository {
  /// Returns the customer's only draft, creating an empty one when needed.
  /// The note id stays stable across later edits.
  Future<Either<Failure, CustomerNote>> activeDraft(String customerId);

  /// Opens the draft, or the latest delivered note when there is no draft.
  /// Creates an empty draft when the customer has no note yet.
  Future<Either<Failure, CustomerNote>> openNote(String customerId);

  /// The open draft, or the latest delivered note. Null when none exists.
  Future<Either<Failure, CustomerNote?>> currentNote(String customerId);

  Future<Either<Failure, CustomerNote>> note(String id);

  /// Draft notes with a due date and items, for the home upcoming list.
  Future<Either<Failure, List<CustomerNote>>> draftNotesWithDue();

  Future<Either<Failure, CustomerNote>> saveLines({
    required String noteId,
    required List<NoteLineDraft> lines,
  });

  Future<Either<Failure, CustomerNote>> setDueOn({
    required String noteId,
    required DateTime? dueOn,
  });
}
