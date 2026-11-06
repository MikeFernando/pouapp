import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/entities/customer_address.dart';
import 'package:pouapp/features/customers/domain/validation/customer_validators.dart';

void main() {
  test('should compare customers by value', () {
    final now = DateTime.utc(2026, 1, 1);
    final customer = Customer(
      id: '1',
      type: CustomerType.company,
      name: 'Mercado Central',
      status: CustomerStatus.active,
      externalSource: CustomerSource.local,
      createdAt: now,
      updatedAt: now,
    );

    expect(
      customer,
      Customer(
        id: '1',
        type: CustomerType.company,
        name: 'Mercado Central',
        status: CustomerStatus.active,
        externalSource: CustomerSource.local,
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(customer.props, isNot(contains('senha')));
  });

  test('should accept a valid CPF and reject a wrong check digit', () {
    expect(isValidCpf('529.982.247-25'), isTrue);
    expect(isValidCpf('52998224724'), isFalse);
    expect(isValidCpf('11111111111'), isFalse);
    expect(isValidCpf('123'), isFalse);
  });

  test('should accept a valid CNPJ and reject a wrong check digit', () {
    expect(isValidCnpj('11.222.333/0001-81'), isTrue);
    expect(isValidCnpj('11222333000180'), isFalse);
    expect(isValidCnpj('00000000000000'), isFalse);
  });

  test(
    'should require the name and validate optional fields by person type',
    () {
      expect(
        validateCustomerInput(
          const CustomerInput(type: CustomerType.individual, name: '   '),
        ),
        CustomerValidationError.nameRequired,
      );
      expect(
        validateCustomerInput(
          const CustomerInput(
            type: CustomerType.individual,
            name: 'João Oliveira',
            document: '52998224724',
          ),
        ),
        CustomerValidationError.invalidDocument,
      );
      expect(
        validateCustomerInput(
          const CustomerInput(
            type: CustomerType.company,
            name: 'Mercado Central',
            document: '11222333000181',
            email: 'contato@mercado.example',
            phone: '(11) 3333-4444',
            mobilePhone: '11988887777',
          ),
        ),
        isNull,
      );
      expect(
        validateCustomerInput(
          const CustomerInput(
            type: CustomerType.individual,
            name: 'João Oliveira',
            email: 'joao',
          ),
        ),
        CustomerValidationError.invalidEmail,
      );
    },
  );

  test('should keep a single primary address', () {
    const first = CustomerAddress(
      id: 'a',
      customerId: 'c',
      label: 'Loja',
      street: 'Rua A',
      number: '1',
      neighborhood: 'Centro',
      city: 'São Paulo',
      state: 'SP',
      isPrimary: true,
    );
    const second = CustomerAddress(
      id: 'b',
      customerId: 'c',
      label: 'Depósito',
      street: 'Rua B',
      number: '2',
      neighborhood: 'Centro',
      city: 'São Paulo',
      state: 'SP',
      isPrimary: false,
    );

    final updated = withSinglePrimaryAddress([first, second], 'b');

    expect(updated.singleWhere((address) => address.isPrimary).id, 'b');
    expect(updated.where((address) => address.isPrimary), hasLength(1));
  });
}
