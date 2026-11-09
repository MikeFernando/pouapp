import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:pouapp/features/customers/domain/usecases/customer_use_cases.dart';
import 'package:pouapp/features/freight/domain/entities/freight_ledger.dart';
import 'package:pouapp/features/freight/domain/repositories/freight_repository.dart';
import 'package:pouapp/features/freight/domain/usecases/freight_use_cases.dart';
import 'package:pouapp/features/freight/presentation/bloc/freight_bloc.dart';
import 'package:pouapp/features/freight/presentation/pages/freight_page.dart';

class _FreightRepository extends Mock implements FreightRepository {}

class _CustomerRepository extends Mock implements CustomerRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const CustomerQuery());
    registerFallbackValue(const CollectFreight('job'));
  });

  testWidgets('should open the freight module and keep delivery unpaid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FreightRepository();
    var ledger = exampleFreightLedger();
    when(() => repository.getLedger()).thenAnswer((_) async => Right(ledger));
    when(() => repository.apply(any())).thenAnswer((invocation) async {
      final change = invocation.positionalArguments.first as FreightChange;
      final update = updateFreightLedger(
        ledger,
        change,
        now: DateTime(2026, 10, 21),
      );
      ledger = update.ledger ?? ledger;
      return Right(ledger);
    });
    final customers = _CustomerRepository();
    when(() => customers.getCustomers(any())).thenAnswer(
      (_) async => const Right(
        CustomerPage(items: [], total: 0, page: 0, pageSize: 100),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => FreightBloc(
            getLedger: GetFreightLedger(repository),
            applyChange: ApplyFreightChange(repository),
            getCustomers: GetCustomers(customers),
          )..add(const FreightRequested()),
          child: FreightBoard(clock: () => DateTime(2026, 10, 21)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Frete'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('freight_combined'))).data,
      'R\$ 400,00',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('freight_received'))).data,
      'R\$ 200,00',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('freight_receivable'))).data,
      'R\$ 200,00',
    );

    await tester.tap(find.byKey(const Key('freight_open_trip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volta para Apiaí'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Parcialmente pago'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('freight_collect_job-volta-ricardo')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('freight_collect_job-volta-ricardo')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('freight_deliver_job-volta-ricardo')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('freight_deliver_job-volta-ricardo')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Entregue'), findsWidgets);
    expect(find.textContaining('Parcialmente pago'), findsOneWidget);
    expect(find.textContaining('Saldo R\$ 100,00'), findsWidgets);
  });
}
