import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_address.dart';
import '../../domain/entities/customer_contact.dart';
import '../../domain/usecases/address_use_cases.dart';
import '../../domain/usecases/contact_use_cases.dart';
import '../../domain/usecases/customer_use_cases.dart';
import '../customer_messages.dart';

enum CustomerDetailsStatus { initial, loading, ready, saving, failure }

class CustomerDetailsState extends Equatable {
  const CustomerDetailsState({
    this.status = CustomerDetailsStatus.initial,
    this.customer,
    this.addresses = const [],
    this.contacts = const [],
    this.message,
    this.messageToken = 0,
  });

  final CustomerDetailsStatus status;
  final Customer? customer;
  final List<CustomerAddress> addresses;
  final List<CustomerContact> contacts;
  final String? message;
  final int messageToken;

  CustomerDetailsState copyWith({
    CustomerDetailsStatus? status,
    Customer? customer,
    List<CustomerAddress>? addresses,
    List<CustomerContact>? contacts,
    String? message,
    int? messageToken,
    bool clearMessage = false,
  }) {
    return CustomerDetailsState(
      status: status ?? this.status,
      customer: customer ?? this.customer,
      addresses: addresses ?? this.addresses,
      contacts: contacts ?? this.contacts,
      message: clearMessage ? null : message ?? this.message,
      messageToken: messageToken ?? this.messageToken,
    );
  }

  @override
  List<Object?> get props => [
    status,
    customer,
    addresses,
    contacts,
    message,
    messageToken,
  ];
}

sealed class CustomerDetailsEvent extends Equatable {
  const CustomerDetailsEvent();

  @override
  List<Object?> get props => [];
}

class CustomerDetailsRequested extends CustomerDetailsEvent {
  const CustomerDetailsRequested(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

class CustomerStatusChangeRequested extends CustomerDetailsEvent {
  const CustomerStatusChangeRequested(this.status);

  final CustomerStatus status;

  @override
  List<Object?> get props => [status];
}

class CustomerAddressSubmitRequested extends CustomerDetailsEvent {
  const CustomerAddressSubmitRequested(this.input, {this.addressId});

  final AddressInput input;
  final String? addressId;

  @override
  List<Object?> get props => [input, addressId];
}

class CustomerAddressDeleteRequested extends CustomerDetailsEvent {
  const CustomerAddressDeleteRequested(this.addressId);

  final String addressId;

  @override
  List<Object?> get props => [addressId];
}

class CustomerPrimaryAddressRequested extends CustomerDetailsEvent {
  const CustomerPrimaryAddressRequested(this.addressId);

  final String addressId;

  @override
  List<Object?> get props => [addressId];
}

class CustomerContactSubmitRequested extends CustomerDetailsEvent {
  const CustomerContactSubmitRequested(this.input, {this.contactId});

  final ContactInput input;
  final String? contactId;

  @override
  List<Object?> get props => [input, contactId];
}

class CustomerContactDeleteRequested extends CustomerDetailsEvent {
  const CustomerContactDeleteRequested(this.contactId);

  final String contactId;

  @override
  List<Object?> get props => [contactId];
}

class CustomerDetailsBloc
    extends Bloc<CustomerDetailsEvent, CustomerDetailsState> {
  CustomerDetailsBloc({
    required this.getCustomerById,
    required this.changeCustomerStatus,
    required this.getCustomerAddresses,
    required this.addCustomerAddress,
    required this.updateCustomerAddress,
    required this.deleteCustomerAddress,
    required this.setPrimaryCustomerAddress,
    required this.getCustomerContacts,
    required this.addCustomerContact,
    required this.updateCustomerContact,
    required this.deleteCustomerContact,
  }) : super(const CustomerDetailsState()) {
    on<CustomerDetailsRequested>(_onRequested);
    on<CustomerStatusChangeRequested>(_onStatus);
    on<CustomerAddressSubmitRequested>(_onAddressSubmit);
    on<CustomerAddressDeleteRequested>(_onAddressDelete);
    on<CustomerPrimaryAddressRequested>(_onPrimaryAddress);
    on<CustomerContactSubmitRequested>(_onContactSubmit);
    on<CustomerContactDeleteRequested>(_onContactDelete);
  }

  final GetCustomerById getCustomerById;
  final ChangeCustomerStatus changeCustomerStatus;
  final GetCustomerAddresses getCustomerAddresses;
  final AddCustomerAddress addCustomerAddress;
  final UpdateCustomerAddress updateCustomerAddress;
  final DeleteCustomerAddress deleteCustomerAddress;
  final SetPrimaryCustomerAddress setPrimaryCustomerAddress;
  final GetCustomerContacts getCustomerContacts;
  final AddCustomerContact addCustomerContact;
  final UpdateCustomerContact updateCustomerContact;
  final DeleteCustomerContact deleteCustomerContact;

  Future<void> _onRequested(
    CustomerDetailsRequested event,
    Emitter<CustomerDetailsState> emit,
  ) async {
    emit(
      state.copyWith(status: CustomerDetailsStatus.loading, clearMessage: true),
    );
    final result = await getCustomerById(event.id);
    await result.fold(
      (failure) async => emit(_failure(state, customerFailureMessage(failure))),
      (customer) async {
        emit(state.copyWith(customer: customer));
        await _loadChildren(customer.id, emit);
      },
    );
  }

  Future<void> _onStatus(
    CustomerStatusChangeRequested event,
    Emitter<CustomerDetailsState> emit,
  ) async {
    final customer = state.customer;
    if (customer == null || state.status == CustomerDetailsStatus.saving) {
      return;
    }
    emit(
      state.copyWith(status: CustomerDetailsStatus.saving, clearMessage: true),
    );
    final result = await changeCustomerStatus(
      ChangeCustomerStatusParams(id: customer.id, status: event.status),
    );
    result.fold(
      (failure) => emit(_ready(state, customerFailureMessage(failure))),
      (updated) => emit(
        state.copyWith(
          status: CustomerDetailsStatus.ready,
          customer: updated,
          message: event.status == CustomerStatus.inactive
              ? 'Cliente desativado.'
              : 'Cliente ativado.',
          messageToken: state.messageToken + 1,
        ),
      ),
    );
  }

  Future<void> _onAddressSubmit(
    CustomerAddressSubmitRequested event,
    Emitter<CustomerDetailsState> emit,
  ) async {
    final customer = state.customer;
    if (customer == null || state.status == CustomerDetailsStatus.saving) {
      return;
    }
    emit(
      state.copyWith(status: CustomerDetailsStatus.saving, clearMessage: true),
    );
    final addressId = event.addressId;
    final result = addressId == null
        ? await addCustomerAddress(event.input)
        : await updateCustomerAddress(
            UpdateAddressParams(id: addressId, input: event.input),
          );
    await result.fold(
      (failure) async => emit(_ready(state, customerFailureMessage(failure))),
      (_) async => _loadChildren(customer.id, emit, message: 'Endereço salvo.'),
    );
  }

  Future<void> _onAddressDelete(
    CustomerAddressDeleteRequested event,
    Emitter<CustomerDetailsState> emit,
  ) async {
    final customer = state.customer;
    if (customer == null || state.status == CustomerDetailsStatus.saving) {
      return;
    }
    emit(
      state.copyWith(status: CustomerDetailsStatus.saving, clearMessage: true),
    );
    final result = await deleteCustomerAddress(
      DeleteAddressParams(customerId: customer.id, addressId: event.addressId),
    );
    await result.fold(
      (failure) async => emit(_ready(state, customerFailureMessage(failure))),
      (_) async =>
          _loadChildren(customer.id, emit, message: 'Endereço excluído.'),
    );
  }

  Future<void> _onPrimaryAddress(
    CustomerPrimaryAddressRequested event,
    Emitter<CustomerDetailsState> emit,
  ) async {
    final customer = state.customer;
    if (customer == null || state.status == CustomerDetailsStatus.saving) {
      return;
    }
    emit(
      state.copyWith(status: CustomerDetailsStatus.saving, clearMessage: true),
    );
    final result = await setPrimaryCustomerAddress(
      SetPrimaryAddressParams(
        customerId: customer.id,
        addressId: event.addressId,
      ),
    );
    await result.fold(
      (failure) async => emit(_ready(state, customerFailureMessage(failure))),
      (_) async => _loadChildren(
        customer.id,
        emit,
        message: 'Endereço principal atualizado.',
      ),
    );
  }

  Future<void> _onContactSubmit(
    CustomerContactSubmitRequested event,
    Emitter<CustomerDetailsState> emit,
  ) async {
    final customer = state.customer;
    if (customer == null || state.status == CustomerDetailsStatus.saving) {
      return;
    }
    emit(
      state.copyWith(status: CustomerDetailsStatus.saving, clearMessage: true),
    );
    final contactId = event.contactId;
    final result = contactId == null
        ? await addCustomerContact(event.input)
        : await updateCustomerContact(
            UpdateContactParams(id: contactId, input: event.input),
          );
    await result.fold(
      (failure) async => emit(_ready(state, customerFailureMessage(failure))),
      (_) async => _loadChildren(customer.id, emit, message: 'Contato salvo.'),
    );
  }

  Future<void> _onContactDelete(
    CustomerContactDeleteRequested event,
    Emitter<CustomerDetailsState> emit,
  ) async {
    final customer = state.customer;
    if (customer == null || state.status == CustomerDetailsStatus.saving) {
      return;
    }
    emit(
      state.copyWith(status: CustomerDetailsStatus.saving, clearMessage: true),
    );
    final result = await deleteCustomerContact(
      DeleteContactParams(customerId: customer.id, contactId: event.contactId),
    );
    await result.fold(
      (failure) async => emit(_ready(state, customerFailureMessage(failure))),
      (_) async =>
          _loadChildren(customer.id, emit, message: 'Contato excluído.'),
    );
  }

  Future<void> _loadChildren(
    String customerId,
    Emitter<CustomerDetailsState> emit, {
    String? message,
  }) async {
    final addressesResult = await getCustomerAddresses(customerId);
    final contactsResult = await getCustomerContacts(customerId);
    if (emit.isDone) return;
    final failure =
        addressesResult.fold((error) => error, (_) => null) ??
        contactsResult.fold((error) => error, (_) => null);
    if (failure != null) {
      emit(_ready(state, customerFailureMessage(failure)));
      return;
    }
    final addresses = addressesResult.getOrElse(() => const []);
    final contacts = contactsResult.getOrElse(() => const []);
    emit(
      state.copyWith(
        status: CustomerDetailsStatus.ready,
        addresses: addresses,
        contacts: contacts,
        message: message,
        messageToken: message == null
            ? state.messageToken
            : state.messageToken + 1,
        clearMessage: message == null,
      ),
    );
  }
}

CustomerDetailsState _failure(CustomerDetailsState state, String message) {
  return state.copyWith(
    status: CustomerDetailsStatus.failure,
    message: message,
    messageToken: state.messageToken + 1,
  );
}

CustomerDetailsState _ready(CustomerDetailsState state, String message) {
  return state.copyWith(
    status: CustomerDetailsStatus.ready,
    message: message,
    messageToken: state.messageToken + 1,
  );
}
