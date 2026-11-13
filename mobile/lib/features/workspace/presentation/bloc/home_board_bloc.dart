import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/home_board_cache.dart';
import '../../domain/entities/home_board.dart';
import '../../domain/entities/street_ledger.dart';
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
  HomeBoardBloc({
    required this.getHomeBoard,
    required this.cache,
  }) : super(const HomeBoardState()) {
    on<HomeBoardRequested>(_onRequested);
  }

  final GetHomeBoard getHomeBoard;
  final HomeBoardCache cache;

  Future<void> _onRequested(
    HomeBoardRequested event,
    Emitter<HomeBoardState> emit,
  ) async {
    final date = event.date ?? isoDate(DateTime.now());
    final cached = cache.read(date: date);

    // Offline-first: show cache immediately; never blank the home on refresh.
    if (state.board == null && cached != null) {
      emit(
        state.copyWith(
          status: HomeBoardStatus.ready,
          board: cached,
          clearMessage: true,
        ),
      );
    } else if (state.board == null) {
      emit(state.copyWith(status: HomeBoardStatus.loading, clearMessage: true));
    }

    final result = await getHomeBoard(date);
    await result.fold(
      (failure) async {
        // Keep working offline from SQLite notes + last cache.
        final fallback = state.board ?? cached ?? emptyHomeBoard();
        emit(
          state.copyWith(
            status: HomeBoardStatus.ready,
            board: fallback,
            clearMessage: true,
          ),
        );
      },
      (board) async {
        await cache.write(board);
        emit(
          state.copyWith(
            status: HomeBoardStatus.ready,
            board: board,
            clearMessage: true,
          ),
        );
      },
    );
  }
}
