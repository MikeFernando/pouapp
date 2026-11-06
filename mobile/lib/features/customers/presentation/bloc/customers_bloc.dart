import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/customer.dart';
import '../../domain/usecases/customer_use_cases.dart';
import '../customer_messages.dart';

enum CustomersStatus { initial, loading, success, loadingMore, failure }

class CustomersState extends Equatable {
  const CustomersState({
    this.status = CustomersStatus.initial,
    this.query = const CustomerQuery(status: CustomerStatus.active),
    this.items = const [],
    this.total = 0,
    this.hasMore = false,
    this.message,
  });

  final CustomersStatus status;
  final CustomerQuery query;
  final List<Customer> items;
  final int total;
  final bool hasMore;
  final String? message;

  CustomersState copyWith({
    CustomersStatus? status,
    CustomerQuery? query,
    List<Customer>? items,
    int? total,
    bool? hasMore,
    String? message,
    bool clearMessage = false,
  }) {
    return CustomersState(
      status: status ?? this.status,
      query: query ?? this.query,
      items: items ?? this.items,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, query, items, total, hasMore, message];
}

sealed class CustomersEvent extends Equatable {
  const CustomersEvent();

  @override
  List<Object?> get props => [];
}

class CustomersRequested extends CustomersEvent {
  const CustomersRequested();
}

class CustomersSearchChanged extends CustomersEvent {
  const CustomersSearchChanged(this.search);

  final String search;

  @override
  List<Object?> get props => [search];
}

class CustomersFilterChanged extends CustomersEvent {
  const CustomersFilterChanged(this.status);

  final CustomerStatus? status;

  @override
  List<Object?> get props => [status];
}

class CustomersLoadMoreRequested extends CustomersEvent {
  const CustomersLoadMoreRequested();
}

class CustomersRefreshRequested extends CustomersEvent {
  const CustomersRefreshRequested();
}

class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  CustomersBloc({required this.getCustomers}) : super(const CustomersState()) {
    on<CustomersRequested>(_onRequested);
    on<CustomersSearchChanged>(_onSearchChanged);
    on<CustomersFilterChanged>(_onFilterChanged);
    on<CustomersLoadMoreRequested>(_onLoadMore);
    on<CustomersRefreshRequested>(_onRefresh);
  }

  final GetCustomers getCustomers;
  int _ticket = 0;

  Future<void> _onRequested(
    CustomersRequested event,
    Emitter<CustomersState> emit,
  ) {
    return _load(emit, state.query, replace: true);
  }

  Future<void> _onSearchChanged(
    CustomersSearchChanged event,
    Emitter<CustomersState> emit,
  ) {
    return _load(
      emit,
      state.query.copyWith(search: event.search, page: 0),
      replace: true,
    );
  }

  Future<void> _onFilterChanged(
    CustomersFilterChanged event,
    Emitter<CustomersState> emit,
  ) {
    return _load(
      emit,
      state.query.copyWith(
        status: event.status,
        clearStatus: event.status == null,
        page: 0,
      ),
      replace: true,
    );
  }

  Future<void> _onLoadMore(
    CustomersLoadMoreRequested event,
    Emitter<CustomersState> emit,
  ) {
    if (!state.hasMore ||
        state.status == CustomersStatus.loading ||
        state.status == CustomersStatus.loadingMore) {
      return Future.value();
    }
    return _load(
      emit,
      state.query.copyWith(page: state.query.page + 1),
      replace: false,
    );
  }

  Future<void> _onRefresh(
    CustomersRefreshRequested event,
    Emitter<CustomersState> emit,
  ) {
    return _load(emit, state.query.copyWith(page: 0), replace: true);
  }

  Future<void> _load(
    Emitter<CustomersState> emit,
    CustomerQuery query, {
    required bool replace,
  }) async {
    final ticket = ++_ticket;
    emit(
      state.copyWith(
        status: replace ? CustomersStatus.loading : CustomersStatus.loadingMore,
        query: query,
        clearMessage: true,
      ),
    );
    final Either<Failure, CustomerPage> result;
    try {
      result = await getCustomers(query);
    } catch (_) {
      if (emit.isDone || ticket != _ticket) return;
      emit(
        state.copyWith(
          status: CustomersStatus.failure,
          message: 'Não foi possível carregar os clientes.',
        ),
      );
      return;
    }
    if (emit.isDone || ticket != _ticket) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CustomersStatus.failure,
          query: replace ? query : query.copyWith(page: query.page - 1),
          message: customerFailureMessage(failure),
        ),
      ),
      (page) => emit(
        state.copyWith(
          status: CustomersStatus.success,
          query: query,
          items: replace ? page.items : [...state.items, ...page.items],
          total: page.total,
          hasMore: page.hasMore,
          clearMessage: true,
        ),
      ),
    );
  }
}
