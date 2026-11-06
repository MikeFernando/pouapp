import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/customers/data/datasources/customer_local_data_source.dart';
import 'package:pouapp/features/customers/data/models/customer_model.dart';
import 'package:pouapp/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/entities/customer_address.dart';
import 'package:pouapp/features/customers/domain/entities/customer_contact.dart';
import 'package:pouapp/features/customers/domain/failures/customer_failures.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late CustomerLocalDataSourceImpl dataSource;
  late CustomerRepositoryImpl repository;
  var sequence = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    sequence = 0;
    dataSource = CustomerLocalDataSourceImpl(
      databasePath: inMemoryDatabasePath,
      seedDemo: false,
      clock: () => DateTime.utc(2026, 3, 1),
      newId: () => 'id-${sequence++}',
    );
    repository = CustomerRepositoryImpl(localDataSource: dataSource);
  });

  tearDown(() async {
    await dataSource.close();
  });

  const primavera = CustomerInput(
    type: CustomerType.company,
    name: 'Restaurante Primavera',
    tradeName: 'Primavera',
    document: '11.222.333/0001-81',
    phone: '(11) 3333-4444',
    mobilePhone: '11988887777',
    externalId: 'demo-ca-primavera',
    externalSource: CustomerSource.contaAzul,
  );

  test('should persist, edit, filter, search and paginate customers', () async {
    final created = await repository.createCustomer(primavera);
    final id = created.getOrElse(() => throw StateError('create')).id;

    final reopened = CustomerRepositoryImpl(localDataSource: dataSource);
    final stored = await reopened.getCustomerById(id);
    final customer = stored.getOrElse(() => throw StateError('read'));
    expect(customer.name, 'Restaurante Primavera');
    expect(customer.document, '11222333000181');
    expect(customer.phone, '1133334444');
    expect(customer.externalId, 'demo-ca-primavera');
    expect(customer.externalSource, CustomerSource.contaAzul);

    await repository.createCustomer(
      const CustomerInput(
        type: CustomerType.company,
        name: 'Hortifruti São José',
        tradeName: 'São José',
        mobilePhone: '31988882222',
      ),
    );
    await repository.createCustomer(
      const CustomerInput(
        type: CustomerType.individual,
        name: 'João Oliveira',
        document: '52998224725',
        status: CustomerStatus.inactive,
      ),
    );

    final byAccent = await repository.getCustomers(
      const CustomerQuery(search: 'sao jose', status: null),
    );
    expect(
      byAccent.getOrElse(() => throw StateError('search')).items.single.name,
      'Hortifruti São José',
    );

    final byTrade = await repository.getCustomers(
      const CustomerQuery(search: 'primavera'),
    );
    expect(
      byTrade.getOrElse(() => throw StateError('trade')).items.single.tradeName,
      'Primavera',
    );

    final byPhone = await repository.getCustomers(
      const CustomerQuery(search: '33334444'),
    );
    expect(
      byPhone.getOrElse(() => throw StateError('phone')).items.single.name,
      'Restaurante Primavera',
    );

    final byDocument = await repository.getCustomers(
      const CustomerQuery(search: '52998224725'),
    );
    expect(
      byDocument
          .getOrElse(() => throw StateError('document'))
          .items
          .single
          .name,
      'João Oliveira',
    );

    final active = await repository.getCustomers(
      const CustomerQuery(status: CustomerStatus.active),
    );
    final activePage = active.getOrElse(() => throw StateError('active'));
    expect(activePage.total, 2);
    expect(activePage.items.map((item) => item.name), [
      'Hortifruti São José',
      'Restaurante Primavera',
    ]);

    final updated = await repository.updateCustomer(
      id: id,
      input: const CustomerInput(
        type: CustomerType.company,
        name: 'Restaurante Primavera',
        tradeName: 'Primavera Grill',
        document: '11222333000181',
        externalSource: CustomerSource.local,
      ),
    );
    expect(
      updated.getOrElse(() => throw StateError('update')).tradeName,
      'Primavera Grill',
    );
    expect(
      updated.getOrElse(() => throw StateError('update')).externalSource,
      CustomerSource.contaAzul,
    );

    final inactive = await repository.changeStatus(
      id: id,
      status: CustomerStatus.inactive,
    );
    expect(
      inactive.getOrElse(() => throw StateError('status')).status,
      CustomerStatus.inactive,
    );

    final duplicate = await repository.createCustomer(primavera);
    expect(duplicate.isLeft(), isTrue);
    duplicate.fold(
      (failure) => expect(failure, const DuplicateExternalCustomerFailure()),
      (_) => fail('duplicated import'),
    );
  });

  test('should page customers without returning the whole table', () async {
    for (var index = 0; index < 25; index++) {
      await repository.createCustomer(
        CustomerInput(
          type: CustomerType.individual,
          name: 'Cliente ${index.toString().padLeft(2, '0')}',
        ),
      );
    }

    final first = await repository.getCustomers(
      const CustomerQuery(page: 0, pageSize: 20, status: null),
    );
    final page = first.getOrElse(() => throw StateError('page'));
    expect(page.items, hasLength(20));
    expect(page.total, 25);
    expect(page.hasMore, isTrue);
    expect(page.items.first.name, 'Cliente 00');

    final second = await repository.getCustomers(
      const CustomerQuery(page: 1, pageSize: 20, status: null),
    );
    expect(
      second.getOrElse(() => throw StateError('page2')).items,
      hasLength(5),
    );
  });

  test(
    'should keep a single primary address and reject another customer',
    () async {
      final customer = await repository.createCustomer(
        const CustomerInput(
          type: CustomerType.company,
          name: 'Mercado Central',
        ),
      );
      final other = await repository.createCustomer(
        const CustomerInput(
          type: CustomerType.company,
          name: 'Padaria Bom Sabor',
        ),
      );
      final customerId = customer.getOrElse(() => throw StateError('c')).id;
      final otherId = other.getOrElse(() => throw StateError('o')).id;

      final first = await repository.addAddress(
        AddressInput(
          customerId: customerId,
          label: 'Loja',
          street: 'Rua A',
          number: '10',
          neighborhood: 'Centro',
          city: 'Curitiba',
          state: 'pr',
          isPrimary: false,
        ),
      );
      final second = await repository.addAddress(
        AddressInput(
          customerId: customerId,
          label: 'Depósito',
          street: 'Rua B',
          number: '20',
          neighborhood: 'Centro',
          city: 'Curitiba',
          state: 'PR',
          isPrimary: true,
        ),
      );
      final firstAddress = first.getOrElse(() => throw StateError('a1'));
      final secondAddress = second.getOrElse(() => throw StateError('a2'));
      expect(firstAddress.isPrimary, isTrue);
      expect(firstAddress.state, 'PR');
      expect(secondAddress.isPrimary, isTrue);

      final addresses = await repository.getAddresses(customerId);
      final current = addresses.getOrElse(() => throw StateError('list'));
      expect(current.where((address) => address.isPrimary), hasLength(1));
      expect(
        current.singleWhere((address) => address.isPrimary).id,
        secondAddress.id,
      );

      final moved = await repository.setPrimaryAddress(
        customerId: customerId,
        addressId: firstAddress.id,
      );
      expect(moved.isRight(), isTrue);
      final afterMove = await repository.getAddresses(customerId);
      expect(
        afterMove
            .getOrElse(() => throw StateError('after'))
            .singleWhere((address) => address.isPrimary)
            .id,
        firstAddress.id,
      );

      final foreign = await repository.deleteAddress(
        customerId: otherId,
        addressId: firstAddress.id,
      );
      expect(
        foreign.fold((failure) => failure, (_) => null),
        const AddressNotFoundFailure(),
      );

      final removed = await repository.deleteAddress(
        customerId: customerId,
        addressId: firstAddress.id,
      );
      expect(removed.isRight(), isTrue);
      final remaining = await repository.getAddresses(customerId);
      final left = remaining.getOrElse(() => throw StateError('left'));
      expect(left, hasLength(1));
      expect(left.single.isPrimary, isTrue);
    },
  );

  test(
    'should manage contacts and promote a new primary after deletion',
    () async {
      final customer = await repository.createCustomer(
        const CustomerInput(
          type: CustomerType.company,
          name: 'Mercado Central',
        ),
      );
      final customerId = customer.getOrElse(() => throw StateError('c')).id;
      final owner = await repository.addContact(
        ContactInput(
          customerId: customerId,
          name: 'Marina Costa',
          role: 'Proprietária',
          phone: '11988887777',
          canReceiveBilling: true,
        ),
      );
      final buyer = await repository.addContact(
        ContactInput(
          customerId: customerId,
          name: 'Paulo Lima',
          role: 'Compras',
          phone: '11977776666',
          isPrimary: true,
        ),
      );
      expect(
        owner.getOrElse(() => throw StateError('owner')).isPrimary,
        isTrue,
      );
      expect(
        buyer.getOrElse(() => throw StateError('buyer')).isPrimary,
        isTrue,
      );
      expect(
        owner.getOrElse(() => throw StateError('owner')).canReceiveBilling,
        isTrue,
      );

      await repository.deleteContact(
        customerId: customerId,
        contactId: buyer.getOrElse(() => throw StateError('buyer')).id,
      );
      final contacts = await repository.getContacts(customerId);
      final left = contacts.getOrElse(() => throw StateError('contacts'));
      expect(left, hasLength(1));
      expect(left.single.isPrimary, isTrue);
      expect(left.single.name, 'Marina Costa');
    },
  );

  test(
    'should seed demo customers once and keep edits after reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pouapp-customers',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final path = '${directory.path}/customers.db';

      CustomerLocalDataSourceImpl open() {
        return CustomerLocalDataSourceImpl(
          databasePath: path,
          seedDemo: true,
          clock: () => DateTime.utc(2026, 3, 1),
          newId: () => 'unused',
        );
      }

      final firstSource = open();
      final first = await CustomerRepositoryImpl(localDataSource: firstSource)
          .getCustomers(const CustomerQuery(pageSize: 20, status: null));
      expect(first.getOrElse(() => throw StateError('seed')).total, 5);
      await firstSource.close();

      final secondSource = open();
      final secondRepository = CustomerRepositoryImpl(
        localDataSource: secondSource,
      );
      final second = await secondRepository.getCustomers(
        const CustomerQuery(pageSize: 20, status: null),
      );
      final page = second.getOrElse(() => throw StateError('again'));
      expect(page.total, 5);
      final joao = page.items.singleWhere(
        (item) => item.name == 'João Oliveira',
      );
      await secondRepository.changeStatus(
        id: joao.id,
        status: CustomerStatus.inactive,
      );
      await secondSource.close();

      final thirdSource = open();
      addTearDown(thirdSource.close);
      final after = await CustomerRepositoryImpl(localDataSource: thirdSource)
          .getCustomers(const CustomerQuery(pageSize: 20, status: null));
      final stored = after.getOrElse(() => throw StateError('after'));
      expect(stored.total, 5);
      expect(
        stored.items.singleWhere((item) => item.id == joao.id).status,
        CustomerStatus.inactive,
      );
    },
  );

  test('should serialize a customer without extra fields', () {
    final now = DateTime.utc(2026, 3, 1);
    final model = CustomerModel(
      id: '1',
      type: CustomerType.individual,
      name: 'João Oliveira',
      document: '52998224725',
      status: CustomerStatus.active,
      externalSource: CustomerSource.local,
      createdAt: now,
      updatedAt: now,
    );

    final map = model.toMap(
      searchName: 'joao oliveira',
      searchTradeName: '',
      searchPhones: '',
      searchDocument: '52998224725',
    );

    expect(map.containsKey('balance'), isFalse);
    expect(CustomerModel.fromMap(map).name, 'João Oliveira');
  });
}
