import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/failures/customer_failures.dart';
import 'package:pouapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:pouapp/features/customers/domain/usecases/customer_use_cases.dart';
import 'package:pouapp/features/customers/domain/validation/customer_validators.dart';

class MockCustomerRepository extends Mock implements CustomerRepository {}

void main() {
  late MockCustomerRepository repository;
  late CreateCustomer createCustomer;
  late ChangeCustomerStatus changeStatus;

  const input = CustomerInput(
    type: CustomerType.individual,
    name: 'João Oliveira',
    document: '52998224725',
  );
  final customer = Customer(
    id: '1',
    type: CustomerType.individual,
    name: 'João Oliveira',
    document: '52998224725',
    status: CustomerStatus.active,
    externalSource: CustomerSource.local,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockCustomerRepository();
    createCustomer = CreateCustomer(repository);
    changeStatus = ChangeCustomerStatus(repository);
  });

  test('should reject an invalid document before touching storage', () async {
    final result = await createCustomer(
      const CustomerInput(
        type: CustomerType.individual,
        name: 'João Oliveira',
        document: '123',
      ),
    );

    expect(
      result,
      const Left(
        InvalidCustomerDataFailure(CustomerValidationError.invalidDocument),
      ),
    );
    verifyZeroInteractions(repository);
  });

  test('should create a valid customer through the repository', () async {
    when(() => repository.createCustomer(input))
        .thenAnswer((_) async => Right(customer));

    final result = await createCustomer(input);

    expect(result, Right(customer));
    verify(() => repository.createCustomer(input)).called(1);
  });

  test('should inactivate a customer through the repository', () async {
    const params = ChangeCustomerStatusParams(
      id: '1',
      status: CustomerStatus.inactive,
    );
    final inactive = Customer(
      id: customer.id,
      type: customer.type,
      name: customer.name,
      document: customer.document,
      status: CustomerStatus.inactive,
      externalSource: customer.externalSource,
      createdAt: customer.createdAt,
      updatedAt: customer.updatedAt,
    );
    when(
      () => repository.changeStatus(id: '1', status: CustomerStatus.inactive),
    ).thenAnswer((_) async => Right(inactive));

    final result = await changeStatus(params);

    expect(result.getOrElse(() => customer).status, CustomerStatus.inactive);
  });
}
