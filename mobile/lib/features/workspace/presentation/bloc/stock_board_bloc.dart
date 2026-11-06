import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/stock_board.dart';
import '../../domain/usecases/workspace_use_cases.dart';
import '../operation_labels.dart';
import 'sales_board_bloc.dart';

class StockBoardState extends Equatable {
  const StockBoardState({
    this.status = BoardStatus.initial,
    this.board,
    this.message,
  });

  final BoardStatus status;
  final StockBoard? board;
  final String? message;

  StockBoardState copyWith({
    BoardStatus? status,
    StockBoard? board,
    String? message,
    bool clearMessage = false,
  }) {
    return StockBoardState(
      status: status ?? this.status,
      board: board ?? this.board,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, board, message];
}

class StockBoardRequested extends Equatable {
  const StockBoardRequested();

  @override
  List<Object?> get props => [];
}

class StockBoardBloc extends Bloc<StockBoardRequested, StockBoardState> {
  StockBoardBloc({required this.getStockBoard})
    : super(const StockBoardState()) {
    on<StockBoardRequested>(_onRequested);
  }

  final GetStockBoard getStockBoard;

  Future<void> _onRequested(
    StockBoardRequested event,
    Emitter<StockBoardState> emit,
  ) async {
    if (state.status == BoardStatus.loading) return;
    emit(state.copyWith(status: BoardStatus.loading, clearMessage: true));
    final result = await getStockBoard(const NoParams());
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
