import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/company_operation.dart';
import '../../domain/usecases/workspace_use_cases.dart';
import '../operation_labels.dart';

enum BoardStatus { initial, loading, ready, failure }

class CompanyOperationState extends Equatable {
  const CompanyOperationState({
    this.status = BoardStatus.initial,
    this.operation,
    this.message,
  });

  final BoardStatus status;
  final CompanyOperation? operation;
  final String? message;

  CompanyOperationState copyWith({
    BoardStatus? status,
    CompanyOperation? operation,
    String? message,
    bool clearMessage = false,
  }) {
    return CompanyOperationState(
      status: status ?? this.status,
      operation: operation ?? this.operation,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, operation, message];
}

sealed class CompanyOperationEvent extends Equatable {
  const CompanyOperationEvent();
}

class CompanyOperationRequested extends CompanyOperationEvent {
  const CompanyOperationRequested();

  @override
  List<Object?> get props => [];
}

class CompanyOperationUpdated extends CompanyOperationEvent {
  const CompanyOperationUpdated(this.operation);

  final CompanyOperation operation;

  @override
  List<Object?> get props => [operation];
}

class CompanyOperationBloc
    extends Bloc<CompanyOperationEvent, CompanyOperationState> {
  CompanyOperationBloc({required this.getOperation})
    : super(const CompanyOperationState()) {
    on<CompanyOperationRequested>(_onRequested);
    on<CompanyOperationUpdated>(_onUpdated);
  }

  final GetCompanyOperation getOperation;

  void _onUpdated(
    CompanyOperationUpdated event,
    Emitter<CompanyOperationState> emit,
  ) {
    emit(
      state.copyWith(
        status: BoardStatus.ready,
        operation: event.operation,
        clearMessage: true,
      ),
    );
  }

  Future<void> _onRequested(
    CompanyOperationRequested event,
    Emitter<CompanyOperationState> emit,
  ) async {
    if (state.status == BoardStatus.loading) return;
    emit(state.copyWith(status: BoardStatus.loading, clearMessage: true));
    try {
      final result = await getOperation(const NoParams());
      result.fold(
        (failure) => emit(
          state.copyWith(
            status: BoardStatus.failure,
            message: operationFailureMessage(failure),
          ),
        ),
        (operation) => emit(
          state.copyWith(
            status: BoardStatus.ready,
            operation: operation,
            clearMessage: true,
          ),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: BoardStatus.failure,
          message: operationFailureMessage(const CacheFailure()),
        ),
      );
    }
  }
}
