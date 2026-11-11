import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/core/error/failures.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/usecases/customer_use_cases.dart';
import 'package:pouapp/features/customers/presentation/bloc/customer_form_bloc.dart';
import 'package:pouapp/features/customers/presentation/widgets/customer_new_sheet.dart';

class MockGetCustomerById extends Mock implements GetCustomerById {}

class MockCreateCustomer extends Mock implements CreateCustomer {}

class MockUpdateCustomer extends Mock implements UpdateCustomer {}

void main() {
  late MockGetCustomerById getCustomerById;
  late MockCreateCustomer createCustomer;
  late MockUpdateCustomer updateCustomer;

  final customer = Customer(
    id: '1',
    type: CustomerType.individual,
    name: 'João Oliveira',
    document: '52998224725',
    status: CustomerStatus.active,
    externalSource: CustomerSource.local,
    createdAt: DateTime.utc(2026, 3, 1),
    updatedAt: DateTime.utc(2026, 3, 1),
  );

  setUpAll(() {
    registerFallbackValue(
      const CustomerInput(type: CustomerType.individual, name: 'João'),
    );
    registerFallbackValue(
      const UpdateCustomerParams(
        id: '1',
        input: CustomerInput(type: CustomerType.individual, name: 'João'),
      ),
    );
  });

  setUp(() {
    getCustomerById = MockGetCustomerById();
    createCustomer = MockCreateCustomer();
    updateCustomer = MockUpdateCustomer();
  });

  Future<void> openSheet(WidgetTester tester) async {
    final bloc = CustomerFormBloc(
      getCustomerById: getCustomerById,
      createCustomer: createCustomer,
      updateCustomer: updateCustomer,
    )..add(const CustomerFormStarted());
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => BlocProvider.value(
                      value: bloc,
                      child: const NewCustomerSheet(),
                    ),
                  );
                },
                child: const Text('abrir'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('should ask only for the name and phone', (tester) async {
    await openSheet(tester);

    expect(find.text('Novo cliente'), findsOneWidget);
    expect(find.text('Nome'), findsOneWidget);
    expect(find.text('Telefone (opcional)'), findsOneWidget);
    expect(find.text('Pessoa física'), findsNothing);
    expect(find.text('Nome fantasia'), findsNothing);
    expect(find.text('E-mail'), findsNothing);
    expect(find.text('Observações'), findsNothing);

    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pump();

    expect(find.text('Informe o nome.'), findsOneWidget);
    verifyZeroInteractions(createCustomer);

    await tester.enterText(
      find.byKey(const Key('customer_name')),
      'João Oliveira',
    );
    await tester.enterText(find.byKey(const Key('customer_phone')), '123');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pump();

    expect(
      find.text('Informe um telefone com DDD e 8 ou 9 dígitos.'),
      findsOneWidget,
    );
    expect(find.text('João Oliveira'), findsOneWidget);
    verifyZeroInteractions(createCustomer);
  });

  testWidgets('should save with name only when phone is empty', (tester) async {
    when(() => createCustomer(any())).thenAnswer((_) async => Right(customer));

    await openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('customer_name')),
      'Dona Maria',
    );
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    final captured = verify(() => createCustomer(captureAny())).captured.single
        as CustomerInput;
    expect(captured.name, 'Dona Maria');
    expect(captured.phone, isNull);
    expect(find.byType(NewCustomerSheet), findsNothing);
  });

  testWidgets('should keep the typed name when saving fails', (tester) async {
    when(() => createCustomer(any()))
        .thenAnswer((_) async => const Left(CacheFailure()));

    await openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('customer_name')),
      'Padaria Bom Sabor',
    );
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível acessar os clientes salvos.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('customer_name')))
          .controller
          ?.text,
      'Padaria Bom Sabor',
    );
    expect(find.byType(NewCustomerSheet), findsOneWidget);
  });

  testWidgets('should block a second tap while the customer is being saved', (
    tester,
  ) async {
    when(() => createCustomer(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return Right(customer);
    });

    await openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('customer_name')),
      'João Oliveira',
    );
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pump();

    expect(find.bySemanticsLabel('Salvando cliente'), findsOneWidget);

    await tester.pumpAndSettle();

    verify(() => createCustomer(any())).called(1);
    expect(find.byType(NewCustomerSheet), findsNothing);
  });
}
