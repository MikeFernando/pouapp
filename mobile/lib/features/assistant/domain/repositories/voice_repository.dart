import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/voice_command.dart';

abstract class VoiceRepository {
  Future<Either<Failure, VoiceOutcome>> submit({
    required String transcript,
    required String executionId,
    VoiceCommand? pending,
    String? choiceId,
    DateTime? today,
    String? contextCustomerId,
    String? contextLabel,
    bool contextFresh = false,
  });

  Future<Either<Failure, VoiceOutcome>> undo(String executionId);

  Future<Either<Failure, Unit>> saveAlias({
    required VoiceAliasKind kind,
    required String alias,
    required String target,
  });
}
