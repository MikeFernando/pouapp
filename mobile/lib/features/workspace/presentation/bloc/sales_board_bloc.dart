import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/sales_board.dart';
import '../../domain/usecases/workspace_use_cases.dart';
import '../operation_labels.dart';

enum BoardStatus { initial, loading, ready, failure }

class SalesBoardState extends Equatable {
  const SalesBoardState({
    this.status = BoardStatus.initial,
    this.board,
    this.message,
  });

  final BoardStatus status;
  final SalesBoard? board;
  final String? message;

  SalesBoardState copyWith({
    BoardStatus? status,
    SalesBoard? board,
    String? message,
    bool clearMessage = false,
  }) {
    return SalesBoardState(
      status: status ?? this.status,
      board: board ?? this.board,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, board, message];
}

class SalesBoardRequested extends Equatable {
  const SalesBoardRequested();

  @override
  List<Object?> get props => [];
}

class SalesBoardBloc extends Bloc<SalesBoardRequested, SalesBoardState> {
  SalesBoardBloc({required this.getSalesBoard})
    : super(const SalesBoardState()) {
    on<SalesBoardRequested>(_onRequested);
  }

  final GetSalesBoard getSalesBoard;

  Future<void> _onRequested(
    SalesBoardRequested event,
    Emitter<SalesBoardState> emit,
  ) async {
    if (state.status == BoardStatus.loading) return;
    emit(state.copyWith(status: BoardStatus.loading, clearMessage: true));
    final result = await getSalesBoard(const NoParams());
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: BoardStatus.failure,
          message: operationFailureMessage(failure),
        ),
      ),
      (board) => emit(
        state.copyWith(
          status: BoardStatus.ready,
          board: board,
          clearMessage: true,
        ),
      ),
    );
  }
}
