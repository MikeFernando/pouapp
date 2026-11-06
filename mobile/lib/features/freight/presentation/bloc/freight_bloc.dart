import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/usecases/customer_use_cases.dart';
import '../../domain/entities/freight_ledger.dart';
import '../../domain/failures/freight_failure.dart';
import '../../domain/usecases/freight_use_cases.dart';

enum FreightBoardStatus { initial, loading, ready, failure }

class FreightPerson extends Equatable {
  const FreightPerson({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

class FreightState extends Equatable {
  const FreightState({
    this.status = FreightBoardStatus.initial,
    this.ledger,
    this.people = const [],
    this.message,
    this.showPending = false,
  });

  final FreightBoardStatus status;
  final FreightLedger? ledger;
  final List<FreightPerson> people;
  final String? message;
  final bool showPending;

  FreightState copyWith({
    FreightBoardStatus? status,
    FreightLedger? ledger,
    List<FreightPerson>? people,
    String? message,
    bool? showPending,
    bool clearMessage = false,
  }) {
    return FreightState(
      status: status ?? this.status,
      ledger: ledger ?? this.ledger,
      people: people ?? this.people,
      message: clearMessage ? null : message ?? this.message,
      showPending: showPending ?? this.showPending,
    );
  }

  @override
  List<Object?> get props => [status, ledger, people, message, showPending];
}

sealed class FreightEvent extends Equatable {
  const FreightEvent();
}

class FreightRequested extends FreightEvent {
  const FreightRequested();

  @override
  List<Object?> get props => [];
}

class FreightChangeSubmitted extends FreightEvent {
  const FreightChangeSubmitted(this.change);

  final FreightChange change;

  @override
  List<Object?> get props => [change];
}

class FreightPendingToggled extends FreightEvent {
  const FreightPendingToggled();

  @override
  List<Object?> get props => [];
}

class FreightBloc extends Bloc<FreightEvent, FreightState> {
  FreightBloc({
    required this.getLedger,
    required this.applyChange,
    required this.getCustomers,
  }) : super(const FreightState()) {
    on<FreightRequested>(_onRequested);
    on<FreightChangeSubmitted>(_onChange);
    on<FreightPendingToggled>(_onToggle);
  }

  final GetFreightLedger getLedger;
  final ApplyFreightChange applyChange;
  final GetCustomers getCustomers;

  Future<void> _onRequested(
    FreightRequested event,
    Emitter<FreightState> emit,
  ) async {
    emit(
      state.copyWith(status: FreightBoardStatus.loading, clearMessage: true),
    );
    final result = await getLedger(const NoParams());
    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: FreightBoardStatus.failure,
            message: 'Não foi possível carregar os fretes.',
          ),
        );
      },
      (ledger) async {
        emit(
          state.copyWith(
            status: FreightBoardStatus.ready,
            ledger: ledger,
            people: await _people(ledger),
            clearMessage: true,
          ),
        );
      },
    );
  }

  Future<void> _onChange(
    FreightChangeSubmitted event,
    Emitter<FreightState> emit,
  ) async {
    final result = await applyChange(event.change);
    result.fold(
      (failure) {
        final message = switch (failure) {
          FreightChangeFailure(:final message) => message,
          _ => 'Não foi possível salvar o frete.',
        };
        emit(state.copyWith(message: message));
      },
      (ledger) {
        emit(
          state.copyWith(
            status: FreightBoardStatus.ready,
            ledger: ledger,
            people: _withJobs(state.people, ledger),
            clearMessage: true,
          ),
        );
      },
    );
  }

  void _onToggle(FreightPendingToggled event, Emitter<FreightState> emit) {
    emit(state.copyWith(showPending: !state.showPending, clearMessage: true));
  }

  Future<List<FreightPerson>> _people(FreightLedger ledger) async {
    final result = await getCustomers(
      const CustomerQuery(pageSize: 100, status: CustomerStatus.active),
    );
    final loaded = result.fold<List<FreightPerson>>(
      (_) => const [],
      (page) => [
        for (final customer in page.items)
          FreightPerson(id: customer.id, name: customer.name),
      ],
    );
    return _withJobs(loaded, ledger);
  }

  List<FreightPerson> _withJobs(
    List<FreightPerson> people,
    FreightLedger ledger,
  ) {
    final byId = {for (final person in people) person.id: person.name};
    for (final job in ledger.jobs) {
      byId.putIfAbsent(job.customerId, () => job.customerName);
    }
    final items = [
      for (final entry in byId.entries)
        FreightPerson(id: entry.key, name: entry.value),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return items;
  }
}
