import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/customer.dart';
import '../../domain/usecases/customer_use_cases.dart';
import '../customer_messages.dart';

enum CustomerFormStatus { initial, loading, ready, saving, success, failure }

class CustomerFormState extends Equatable {
  const CustomerFormState({
    this.status = CustomerFormStatus.initial,
    this.customerId,
    this.customer,
    this.message,
    this.messageToken = 0,
  });

  final CustomerFormStatus status;
  final String? customerId;
  final Customer? customer;
  final String? message;
  final int messageToken;

  bool get saved => status == CustomerFormStatus.success;

  CustomerFormState copyWith({
    CustomerFormStatus? status,
    String? customerId,
    Customer? customer,
    String? message,
    int? messageToken,
    bool clearMessage = false,
  }) {
    return CustomerFormState(
      status: status ?? this.status,
      customerId: customerId ?? this.customerId,
      customer: customer ?? this.customer,
      message: clearMessage ? null : message ?? this.message,
      messageToken: messageToken ?? this.messageToken,
    );
  }

  @override
  List<Object?> get props => [
    status,
    customerId,
    customer,
    message,
    messageToken,
  ];
}

sealed class CustomerFormEvent extends Equatable {
  const CustomerFormEvent();

  @override
  List<Object?> get props => [];
}

class CustomerFormStarted extends CustomerFormEvent {
  const CustomerFormStarted({this.customerId});

  final String? customerId;

  @override
  List<Object?> get props => [customerId];
}

class CustomerFormSubmitted extends CustomerFormEvent {
  const CustomerFormSubmitted(this.input);

  final CustomerInput input;

  @override
  List<Object?> get props => [input];
}

class CustomerFormBloc extends Bloc<CustomerFormEvent, CustomerFormState> {
  CustomerFormBloc({
    required this.getCustomerById,
    required this.createCustomer,
    required this.updateCustomer,
  }) : super(const CustomerFormState()) {
    on<CustomerFormStarted>(_onStarted);
    on<CustomerFormSubmitted>(_onSubmitted);
  }

  final GetCustomerById getCustomerById;
  final CreateCustomer createCustomer;
  final UpdateCustomer updateCustomer;

  Future<void> _onStarted(
    CustomerFormStarted event,
    Emitter<CustomerFormState> emit,
  ) async {
    emit(
      state.copyWith(
        status: CustomerFormStatus.loading,
        customerId: event.customerId,
        clearMessage: true,
      ),
    );
    final customerId = event.customerId;
    if (customerId == null) {
      emit(state.copyWith(status: CustomerFormStatus.ready));
      return;
    }
    final result = await getCustomerById(customerId);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CustomerFormStatus.failure,
          message: customerFailureMessage(failure),
          messageToken: state.messageToken + 1,
        ),
      ),
      (customer) => emit(
        state.copyWith(
          status: CustomerFormStatus.ready,
          customer: customer,
          customerId: customer.id,
          clearMessage: true,
        ),
      ),
    );
  }

  Future<void> _onSubmitted(
    CustomerFormSubmitted event,
    Emitter<CustomerFormState> emit,
  ) async {
    if (state.status == CustomerFormStatus.saving) return;
    emit(state.copyWith(status: CustomerFormStatus.saving, clearMessage: true));
    final customerId = state.customerId;
    final result = customerId == null
        ? await createCustomer(event.input)
        : await updateCustomer(
            UpdateCustomerParams(id: customerId, input: event.input),
          );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CustomerFormStatus.ready,
          message: customerFailureMessage(failure),
          messageToken: state.messageToken + 1,
        ),
      ),
      (customer) => emit(
        state.copyWith(
          status: CustomerFormStatus.success,
          customer: customer,
          customerId: customer.id,
          clearMessage: true,
        ),
      ),
    );
  }
}
