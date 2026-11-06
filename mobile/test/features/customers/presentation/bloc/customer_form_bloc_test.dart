import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/usecases/customer_use_cases.dart';
import 'package:pouapp/features/customers/presentation/bloc/customer_form_bloc.dart';

class MockGetCustomerById extends Mock implements GetCustomerById {}

class MockCreateCustomer extends Mock implements CreateCustomer {}

class MockUpdateCustomer extends Mock implements UpdateCustomer {}

void main() {
  late MockGetCustomerById getCustomerById;
  late MockCreateCustomer createCustomer;
  late MockUpdateCustomer updateCustomer;

  const input = CustomerInput(
    type: CustomerType.individual,
    name: 'João Oliveira',
  );
  final customer = Customer(
    id: '1',
    type: CustomerType.individual,
    name: 'João Oliveira',
    status: CustomerStatus.active,
    externalSource: CustomerSource.local,
    createdAt: DateTime.utc(2026, 3, 1),
    updatedAt: DateTime.utc(2026, 3, 1),
  );

  setUpAll(() {
    registerFallbackValue(input);
    registerFallbackValue(const UpdateCustomerParams(id: '1', input: input));
  });

  setUp(() {
    getCustomerById = MockGetCustomerById();
    createCustomer = MockCreateCustomer();
    updateCustomer = MockUpdateCustomer();
  });

  CustomerFormBloc buildBloc() {
    return CustomerFormBloc(
      getCustomerById: getCustomerById,
      createCustomer: createCustomer,
      updateCustomer: updateCustomer,
    );
  }

  blocTest<CustomerFormBloc, CustomerFormState>(
    'should create a customer and keep the form ready when saving fails',
    build: () {
      when(() => createCustomer(any()))
          .thenAnswer((_) async => const Left(CacheFailure()));
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const CustomerFormStarted());
      await bloc.stream.firstWhere(
        (state) => state.status == CustomerFormStatus.ready,
      );
      bloc.add(const CustomerFormSubmitted(input));
    },
    verify: (bloc) {
      expect(bloc.state.status, CustomerFormStatus.ready);
      expect(bloc.state.saved, isFalse);
      expect(
        bloc.state.message,
        'Não foi possível acessar os clientes salvos.',
      );
      verify(() => createCustomer(input)).called(1);
    },
  );

  blocTest<CustomerFormBloc, CustomerFormState>(
    'should update an existing customer',
    build: () {
      when(() => getCustomerById('1')).thenAnswer((_) async => Right(customer));
      when(() => updateCustomer(any()))
          .thenAnswer((_) async => Right(customer));
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const CustomerFormStarted(customerId: '1'));
      await bloc.stream.firstWhere((state) => state.customer != null);
      bloc.add(const CustomerFormSubmitted(input));
    },
    verify: (bloc) {
      expect(bloc.state.saved, isTrue);
      expect(bloc.state.customerId, '1');
      verify(() => updateCustomer(any())).called(1);
      verifyNever(() => createCustomer(any()));
    },
  );
}
