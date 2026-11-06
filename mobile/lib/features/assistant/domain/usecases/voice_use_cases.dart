import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/voice_command.dart';
import '../repositories/voice_repository.dart';

class SubmitVoiceParams extends Equatable {
  const SubmitVoiceParams({
    required this.transcript,
    required this.executionId,
    this.pending,
    this.choiceId,
    this.today,
    this.contextCustomerId,
    this.contextLabel,
    this.contextFresh = false,
  });

  final String transcript;
  final String executionId;
  final VoiceCommand? pending;
  final String? choiceId;
  final DateTime? today;
  final String? contextCustomerId;
  final String? contextLabel;
  final bool contextFresh;

  @override
  List<Object?> get props => [
    transcript,
    executionId,
    pending,
    choiceId,
    today,
    contextCustomerId,
    contextLabel,
    contextFresh,
  ];
}

class SubmitVoiceCommand implements UseCase<VoiceOutcome, SubmitVoiceParams> {
  SubmitVoiceCommand(this.repository);

  final VoiceRepository repository;

  @override
  Future<Either<Failure, VoiceOutcome>> call(SubmitVoiceParams params) {
    return repository.submit(
      transcript: params.transcript,
      executionId: params.executionId,
      pending: params.pending,
      choiceId: params.choiceId,
      today: params.today,
      contextCustomerId: params.contextCustomerId,
      contextLabel: params.contextLabel,
      contextFresh: params.contextFresh,
    );
  }
}

class UndoVoiceCommand implements UseCase<VoiceOutcome, String> {
  UndoVoiceCommand(this.repository);

  final VoiceRepository repository;

  @override
  Future<Either<Failure, VoiceOutcome>> call(String executionId) {
    return repository.undo(executionId);
  }
}

class SaveVoiceAliasParams extends Equatable {
  const SaveVoiceAliasParams({
    required this.kind,
    required this.alias,
    required this.target,
  });

  final VoiceAliasKind kind;
  final String alias;
  final String target;

  @override
  List<Object?> get props => [kind, alias, target];
}

class SaveVoiceAlias implements UseCase<Unit, SaveVoiceAliasParams> {
  SaveVoiceAlias(this.repository);

  final VoiceRepository repository;

  @override
  Future<Either<Failure, Unit>> call(SaveVoiceAliasParams params) {
    return repository.saveAlias(
      kind: params.kind,
      alias: params.alias,
      target: params.target,
    );
  }
}
