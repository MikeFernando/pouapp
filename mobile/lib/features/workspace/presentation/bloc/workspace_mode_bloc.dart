import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/workspace_mode.dart';
import '../../domain/usecases/workspace_use_cases.dart';
import '../operation_labels.dart';

enum WorkspaceModeStatus { loading, ready, failure }

class WorkspaceModeState extends Equatable {
  const WorkspaceModeState({
    this.status = WorkspaceModeStatus.loading,
    this.mode = WorkspaceMode.rua,
    this.message,
  });

  final WorkspaceModeStatus status;
  final WorkspaceMode mode;
  final String? message;

  WorkspaceModeState copyWith({
    WorkspaceModeStatus? status,
    WorkspaceMode? mode,
    String? message,
    bool clearMessage = false,
  }) {
    return WorkspaceModeState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, mode, message];
}

sealed class WorkspaceModeEvent extends Equatable {
  const WorkspaceModeEvent();

  @override
  List<Object?> get props => [];
}

class WorkspaceModeRequested extends WorkspaceModeEvent {
  const WorkspaceModeRequested();
}

class WorkspaceModeSelected extends WorkspaceModeEvent {
  const WorkspaceModeSelected(this.mode);

  final WorkspaceMode mode;

  @override
  List<Object?> get props => [mode];
}

class WorkspaceModeBloc extends Bloc<WorkspaceModeEvent, WorkspaceModeState> {
  WorkspaceModeBloc({required this.getMode, required this.saveMode})
    : super(const WorkspaceModeState()) {
    on<WorkspaceModeRequested>(_onRequested);
    on<WorkspaceModeSelected>(_onSelected);
  }

  final GetWorkspaceMode getMode;
  final SaveWorkspaceMode saveMode;

  Future<void> _onRequested(
    WorkspaceModeRequested event,
    Emitter<WorkspaceModeState> emit,
  ) async {
    if (state.status != WorkspaceModeStatus.loading || state.message != null) {
      emit(
        state.copyWith(status: WorkspaceModeStatus.loading, clearMessage: true),
      );
    }
    final result = await getMode(const NoParams());
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: WorkspaceModeStatus.failure,
          message: operationFailureMessage(failure),
        ),
      ),
      (mode) => emit(
        state.copyWith(
          status: WorkspaceModeStatus.ready,
          mode: mode,
          clearMessage: true,
        ),
      ),
    );
  }

  Future<void> _onSelected(
    WorkspaceModeSelected event,
    Emitter<WorkspaceModeState> emit,
  ) async {
    if (state.mode == event.mode && state.status == WorkspaceModeStatus.ready) {
      return;
    }
    final previous = state.mode;
    emit(
      state.copyWith(
        status: WorkspaceModeStatus.ready,
        mode: event.mode,
        clearMessage: true,
      ),
    );
    final result = await saveMode(event.mode);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: WorkspaceModeStatus.ready,
          mode: previous,
          message: operationFailureMessage(failure),
        ),
      ),
      (_) {},
    );
  }
}
