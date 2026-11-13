import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/usecases/customer_use_cases.dart';
import 'package:pouapp/features/customers/presentation/bloc/customers_bloc.dart';
import 'package:pouapp/features/customers/presentation/pages/customers_page.dart';

class MockGetCustomers extends Mock implements GetCustomers {}

void main() {
  late MockGetCustomers getCustomers;

  final customer = Customer(
    id: '1',
    type: CustomerType.company,
    name: 'Restaurante Primavera',
    tradeName: 'Primavera',
    phone: '1133334444',
    document: '11222333000181',
    status: CustomerStatus.active,
    externalSource: CustomerSource.contaAzul,
    createdAt: DateTime.utc(2026, 3, 1),
    updatedAt: DateTime.utc(2026, 3, 1),
  );

  setUpAll(() {
    registerFallbackValue(const CustomerQuery());
  });

  setUp(() {
    getCustomers = MockGetCustomers();
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) =>
              CustomersBloc(getCustomers: getCustomers)
                ..add(const CustomersRequested()),
          child: const CustomersView(),
        ),
      ),
    );
  }

  testWidgets('should show a loading indicator and then the customers', (
    tester,
  ) async {
    when(() => getCustomers(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return Right(
        CustomerPage(items: [customer], total: 1, page: 0, pageSize: 20),
      );
    });

    await pumpList(tester);

    expect(find.bySemanticsLabel('Carregando clientes'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Restaurante Primavera'), findsOneWidget);
    expect(find.textContaining('Primavera'), findsWidgets);
    expect(find.textContaining('Pessoa jurídica'), findsOneWidget);
    expect(find.text('Regular'), findsWidgets);
    expect(find.byKey(const Key('customer_empty')), findsNothing);
  });

  testWidgets('should show an empty state and search from the field', (
    tester,
  ) async {
    when(() => getCustomers(any())).thenAnswer((invocation) async {
      final query = invocation.positionalArguments.first as CustomerQuery;
      final items = query.search.isEmpty ? [customer] : const <Customer>[];
      return Right(
        CustomerPage(items: items, total: items.length, page: 0, pageSize: 20),
      );
    });

    await pumpList(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('customer_search')), 'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer_empty')), findsOneWidget);
    expect(find.text('Nenhum cliente encontrado.'), findsOneWidget);
    verify(
      () => getCustomers(
        const CustomerQuery(search: 'zzz', status: CustomerStatus.active),
      ),
    ).called(1);
  });

  testWidgets('should filter inactive customers and report a load error', (
    tester,
  ) async {
    var calls = 0;
    when(() => getCustomers(any())).thenAnswer((invocation) async {
      calls += 1;
      if (calls == 1) return const Left(CacheFailure());
      final query = invocation.positionalArguments.first as CustomerQuery;
      expect(query.status, CustomerStatus.inactive);
      return const Right(
        CustomerPage(items: [], total: 0, page: 0, pageSize: 20),
      );
    });

    await pumpList(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível acessar os clientes salvos.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('customer_filter_inactive')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer_empty')), findsOneWidget);
  });
}
