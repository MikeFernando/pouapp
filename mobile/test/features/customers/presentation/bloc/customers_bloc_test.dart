import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/usecases/customer_use_cases.dart';
import 'package:pouapp/features/customers/presentation/bloc/customers_bloc.dart';

class MockGetCustomers extends Mock implements GetCustomers {}

void main() {
  late MockGetCustomers getCustomers;

  final createdAt = DateTime.utc(2026, 3, 1);
  final primavera = Customer(
    id: '1',
    type: CustomerType.company,
    name: 'Restaurante Primavera',
    tradeName: 'Primavera',
    status: CustomerStatus.active,
    externalSource: CustomerSource.local,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
  final mercado = Customer(
    id: '2',
    type: CustomerType.company,
    name: 'Mercado Central',
    status: CustomerStatus.active,
    externalSource: CustomerSource.local,
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  setUpAll(() {
    registerFallbackValue(const CustomerQuery());
  });

  setUp(() {
    getCustomers = MockGetCustomers();
  });

  CustomerPage pageOf(
    List<Customer> items, {
    required int total,
    required int page,
  }) {
    return CustomerPage(items: items, total: total, page: page, pageSize: 20);
  }

  blocTest<CustomersBloc, CustomersState>(
    'should load the first page of active customers',
    build: () {
      when(
        () => getCustomers(any()),
      ).thenAnswer((_) async => Right(pageOf([primavera], total: 1, page: 0)));
      return CustomersBloc(getCustomers: getCustomers);
    },
    act: (bloc) => bloc.add(const CustomersRequested()),
    expect: () => [
      isA<CustomersState>().having(
        (state) => state.status,
        'status',
        CustomersStatus.loading,
      ),
      isA<CustomersState>()
          .having((state) => state.status, 'status', CustomersStatus.success)
          .having((state) => state.items.single.name, 'name', primavera.name)
          .having((state) => state.hasMore, 'hasMore', false),
    ],
  );

  blocTest<CustomersBloc, CustomersState>(
    'should search, filter and append the next page',
    build: () {
      when(() => getCustomers(any())).thenAnswer((invocation) async {
        final query = invocation.positionalArguments.first as CustomerQuery;
        if (query.page == 1) {
          return Right(pageOf([mercado], total: 25, page: 1));
        }
        if (query.status == CustomerStatus.inactive) {
          return Right(pageOf(const [], total: 0, page: 0));
        }
        return Right(pageOf([primavera], total: 25, page: 0));
      });
      return CustomersBloc(getCustomers: getCustomers);
    },
    act: (bloc) async {
      bloc.add(const CustomersRequested());
      await bloc.stream.firstWhere(
        (state) => state.status == CustomersStatus.success,
      );
      bloc.add(const CustomersSearchChanged('primavera'));
      await bloc.stream.firstWhere(
        (state) =>
            state.status == CustomersStatus.success &&
            state.query.search == 'primavera',
      );
      bloc.add(const CustomersLoadMoreRequested());
      await bloc.stream.firstWhere((state) => state.items.length == 2);
      bloc.add(const CustomersFilterChanged(CustomerStatus.inactive));
    },
    verify: (bloc) {
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.query.status, CustomerStatus.inactive);
      verify(
        () => getCustomers(
          const CustomerQuery(
            search: 'primavera',
            status: CustomerStatus.active,
          ),
        ),
      ).called(1);
    },
  );

  blocTest<CustomersBloc, CustomersState>(
    'should expose a failure when the query cannot be read',
    build: () {
      when(() => getCustomers(any()))
          .thenAnswer((_) async => const Left(CacheFailure()));
      return CustomersBloc(getCustomers: getCustomers);
    },
    act: (bloc) => bloc.add(const CustomersRequested()),
    expect: () => [
      isA<CustomersState>().having(
        (state) => state.status,
        'status',
        CustomersStatus.loading,
      ),
      isA<CustomersState>()
          .having((state) => state.status, 'status', CustomersStatus.failure)
          .having(
            (state) => state.message,
            'message',
            'Não foi possível acessar os clientes salvos.',
          ),
    ],
  );
}
