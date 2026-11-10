import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/home_board.dart';
import '../../domain/usecases/home_use_cases.dart';

enum HomeBoardStatus { initial, loading, ready, failure }

class HomeBoardState extends Equatable {
  const HomeBoardState({
    this.status = HomeBoardStatus.initial,
    this.board,
    this.message,
  });

  final HomeBoardStatus status;
  final HomeBoard? board;
  final String? message;

  HomeBoardState copyWith({
    HomeBoardStatus? status,
    HomeBoard? board,
    String? message,
    bool clearMessage = false,
  }) {
    return HomeBoardState(
      status: status ?? this.status,
      board: board ?? this.board,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, board, message];
}

sealed class HomeBoardEvent extends Equatable {
  const HomeBoardEvent();
}

class HomeBoardRequested extends HomeBoardEvent {
  const HomeBoardRequested({this.date});

  final String? date;

  @override
  List<Object?> get props => [date];
}

class HomeBoardBloc extends Bloc<HomeBoardEvent, HomeBoardState> {
  HomeBoardBloc({required this.getHomeBoard}) : super(const HomeBoardState()) {
    on<HomeBoardRequested>(_onRequested);
  }

  final GetHomeBoard getHomeBoard;

  Future<void> _onRequested(
    HomeBoardRequested event,
    Emitter<HomeBoardState> emit,
  ) async {
    emit(state.copyWith(status: HomeBoardStatus.loading, clearMessage: true));
    final result = await getHomeBoard(event.date);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: HomeBoardStatus.failure,
          message: switch (failure) {
            NetworkFailure() => 'Sem conexão com a API.',
            _ => 'Não foi possível carregar a home.',
          },
        ),
      ),
      (board) => emit(
        state.copyWith(
          status: HomeBoardStatus.ready,
          board: board,
          clearMessage: true,
        ),
      ),
    );
  }
}
