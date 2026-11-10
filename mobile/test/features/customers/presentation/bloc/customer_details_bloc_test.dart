import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/entities/customer_address.dart';
import 'package:pouapp/features/customers/domain/entities/customer_contact.dart';
import 'package:pouapp/features/customers/domain/usecases/address_use_cases.dart';
import 'package:pouapp/features/customers/domain/usecases/contact_use_cases.dart';
import 'package:pouapp/features/customers/domain/usecases/customer_use_cases.dart';
import 'package:pouapp/features/customers/presentation/bloc/customer_details_bloc.dart';

class MockGetCustomerById extends Mock implements GetCustomerById {}

class MockChangeCustomerStatus extends Mock implements ChangeCustomerStatus {}

class MockGetCustomerAddresses extends Mock implements GetCustomerAddresses {}

class MockAddCustomerAddress extends Mock implements AddCustomerAddress {}

class MockUpdateCustomerAddress extends Mock implements UpdateCustomerAddress {}

class MockDeleteCustomerAddress extends Mock implements DeleteCustomerAddress {}

class MockSetPrimaryCustomerAddress extends Mock
    implements SetPrimaryCustomerAddress {}

class MockGetCustomerContacts extends Mock implements GetCustomerContacts {}

class MockAddCustomerContact extends Mock implements AddCustomerContact {}

class MockUpdateCustomerContact extends Mock implements UpdateCustomerContact {}

class MockDeleteCustomerContact extends Mock implements DeleteCustomerContact {}

void main() {
  late MockGetCustomerById getCustomerById;
  late MockChangeCustomerStatus changeCustomerStatus;
  late MockGetCustomerAddresses getCustomerAddresses;
  late MockAddCustomerAddress addCustomerAddress;
  late MockUpdateCustomerAddress updateCustomerAddress;
  late MockDeleteCustomerAddress deleteCustomerAddress;
  late MockSetPrimaryCustomerAddress setPrimaryCustomerAddress;
  late MockGetCustomerContacts getCustomerContacts;
  late MockAddCustomerContact addCustomerContact;
  late MockUpdateCustomerContact updateCustomerContact;
  late MockDeleteCustomerContact deleteCustomerContact;

  final customer = Customer(
    id: '1',
    type: CustomerType.company,
    name: 'Mercado Central',
    status: CustomerStatus.active,
    externalSource: CustomerSource.local,
    createdAt: DateTime.utc(2026, 3, 1),
    updatedAt: DateTime.utc(2026, 3, 1),
  );
  const address = CustomerAddress(
    id: 'a',
    customerId: '1',
    label: 'Loja',
    street: 'Rua A',
    number: '10',
    neighborhood: 'Centro',
    city: 'Curitiba',
    state: 'PR',
    isPrimary: false,
  );
  const input = AddressInput(
    customerId: '1',
    label: 'Depósito',
    street: 'Rua B',
    number: '20',
    neighborhood: 'Centro',
    city: 'Curitiba',
    state: 'PR',
    isPrimary: true,
  );

  setUpAll(() {
    registerFallbackValue(
      const ChangeCustomerStatusParams(id: '1', status: CustomerStatus.active),
    );
    registerFallbackValue(input);
    registerFallbackValue(const UpdateAddressParams(id: 'a', input: input));
    registerFallbackValue(
      const DeleteAddressParams(customerId: '1', addressId: 'a'),
    );
    registerFallbackValue(
      const SetPrimaryAddressParams(customerId: '1', addressId: 'a'),
    );
    registerFallbackValue(
      const ContactInput(customerId: '1', name: 'Marina', phone: '11988887777'),
    );
    registerFallbackValue(
      const UpdateContactParams(
        id: 'c',
        input: ContactInput(
          customerId: '1',
          name: 'Marina',
          phone: '11988887777',
        ),
      ),
    );
    registerFallbackValue(
      const DeleteContactParams(customerId: '1', contactId: 'c'),
    );
  });

  setUp(() {
    getCustomerById = MockGetCustomerById();
    changeCustomerStatus = MockChangeCustomerStatus();
    getCustomerAddresses = MockGetCustomerAddresses();
    addCustomerAddress = MockAddCustomerAddress();
    updateCustomerAddress = MockUpdateCustomerAddress();
    deleteCustomerAddress = MockDeleteCustomerAddress();
    setPrimaryCustomerAddress = MockSetPrimaryCustomerAddress();
    getCustomerContacts = MockGetCustomerContacts();
    addCustomerContact = MockAddCustomerContact();
    updateCustomerContact = MockUpdateCustomerContact();
    deleteCustomerContact = MockDeleteCustomerContact();
    when(() => getCustomerById('1')).thenAnswer((_) async => Right(customer));
    when(() => getCustomerAddresses('1'))
        .thenAnswer((_) async => const Right([address]));
    when(() => getCustomerContacts('1'))
        .thenAnswer((_) async => const Right([]));
  });

  CustomerDetailsBloc buildBloc() {
    return CustomerDetailsBloc(
      getCustomerById: getCustomerById,
      changeCustomerStatus: changeCustomerStatus,
      getCustomerAddresses: getCustomerAddresses,
      addCustomerAddress: addCustomerAddress,
      updateCustomerAddress: updateCustomerAddress,
      deleteCustomerAddress: deleteCustomerAddress,
      setPrimaryCustomerAddress: setPrimaryCustomerAddress,
      getCustomerContacts: getCustomerContacts,
      addCustomerContact: addCustomerContact,
      updateCustomerContact: updateCustomerContact,
      deleteCustomerContact: deleteCustomerContact,
    );
  }

  blocTest<CustomerDetailsBloc, CustomerDetailsState>(
    'should inactivate the loaded customer',
    build: () {
      final inactive = Customer(
        id: customer.id,
        type: customer.type,
        name: customer.name,
        status: CustomerStatus.inactive,
        externalSource: customer.externalSource,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
      );
      when(() => changeCustomerStatus(any()))
          .thenAnswer((_) async => Right(inactive));
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const CustomerDetailsRequested('1'));
      await bloc.stream.firstWhere(
        (state) => state.status == CustomerDetailsStatus.ready,
      );
      bloc.add(const CustomerStatusChangeRequested(CustomerStatus.inactive));
    },
    verify: (bloc) {
      expect(bloc.state.customer?.status, CustomerStatus.inactive);
      expect(bloc.state.addresses.single.label, 'Loja');
      expect(bloc.state.message, 'Cliente desativado.');
    },
  );

  blocTest<CustomerDetailsBloc, CustomerDetailsState>(
    'should reload addresses after setting a new primary',
    build: () {
      when(() => setPrimaryCustomerAddress(any()))
          .thenAnswer((_) async => const Right(unit));
      var calls = 0;
      when(() => getCustomerAddresses('1')).thenAnswer((_) async {
        calls += 1;
        if (calls == 1) return const Right([address]);
        return Right([
          CustomerAddress(
            id: address.id,
            customerId: address.customerId,
            label: address.label,
            street: address.street,
            number: address.number,
            neighborhood: address.neighborhood,
            city: address.city,
            state: address.state,
            isPrimary: true,
          ),
        ]);
      });
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const CustomerDetailsRequested('1'));
      await bloc.stream.firstWhere(
        (state) => state.status == CustomerDetailsStatus.ready,
      );
      bloc.add(const CustomerPrimaryAddressRequested('a'));
    },
    verify: (bloc) {
      expect(bloc.state.addresses.single.isPrimary, isTrue);
      expect(bloc.state.message, 'Endereço principal atualizado.');
    },
  );
}
