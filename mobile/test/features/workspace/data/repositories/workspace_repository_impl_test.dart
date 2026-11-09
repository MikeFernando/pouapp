import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/features/workspace/data/datasources/workspace_local_data_source.dart';
import 'package:pouapp/features/workspace/data/datasources/workspace_simulated_data_source.dart';
import 'package:pouapp/features/workspace/data/repositories/workspace_repository_impl.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockWorkspaceLocalDataSource extends Mock
    implements WorkspaceLocalDataSource {}

void main() {
  late WorkspaceRepositoryImpl repository;
  late MockWorkspaceLocalDataSource localDataSource;
  late WorkspaceSimulatedDataSource simulatedDataSource;

  setUp(() {
    localDataSource = MockWorkspaceLocalDataSource();
    when(() => localDataSource.readStreetLedger()).thenReturn(null);
    simulatedDataSource = WorkspaceSimulatedDataSource();
    repository = WorkspaceRepositoryImpl(
      localDataSource: localDataSource,
      simulatedDataSource: simulatedDataSource,
    );
  });

  test('should return one company record without mixing units', () async {
    final result = await repository.getOperation();

    result.fold((_) => fail('expected the company operation'), (operation) {
      expect(operation.summary.soldCents, 0);
      expect(operation.summary.receivedCents, 0);
      expect(operation.summary.receivableCents, isNull);
      expect(operation.summary.payableCents, isNull);
      expect(operation.receipts, isEmpty);
      expect(operation.team, isEmpty);
      expect(operation.sales, isEmpty);
      expect(
        operation.street.orders.where((order) => order.fromSeed),
        isNotEmpty,
      );
      expect(
        operation.products
            .singleWhere((product) => product.id == 'product-banana')
            .available,
        40,
      );
    });
  });

  test('should keep a street sale after a new read', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    WorkspaceRepositoryImpl build() {
      return WorkspaceRepositoryImpl(
        localDataSource: WorkspaceLocalDataSourceImpl(
          sharedPreferences: preferences,
        ),
        simulatedDataSource: WorkspaceSimulatedDataSource(),
      );
    }

    final saved = await build().applyStreetChange(
      const SaveSale(
        visitId: 'visit-primavera',
        customerId: 'demo-customer-primavera',
        customerName: 'Restaurante Primavera',
        lines: [
          SaleLine(
            productName: 'Alface crespa',
            quantity: 2,
            unit: SaleUnit.bunch,
            unitPriceCents: 350,
          ),
        ],
      ),
    );

    final again = await build().getOperation();
    saved.fold((_) => fail('expected to save'), (operation) {
      expect(operation.summary.soldCents, 700);
      expect(operation.summary.receivedCents, 0);
    });
    again.fold((_) => fail('expected to read'), (operation) {
      expect(operation.summary.soldCents, 700);
      expect(operation.summary.receivedCents, 0);
      expect(operation.sales.single.code, '1044');
      expect(
        operation.street.orders.any((order) => order.code == '1044'),
        isTrue,
      );
    });
  });

  test('collecting an old balance does not create a sale', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = WorkspaceRepositoryImpl(
      localDataSource: WorkspaceLocalDataSourceImpl(
        sharedPreferences: preferences,
      ),
      simulatedDataSource: WorkspaceSimulatedDataSource(),
    );

    final paid = await repository.applyStreetChange(
      const RegisterPayment(
        visitId: 'visit-primavera',
        customerId: 'demo-customer-primavera',
        amountCents: 5000,
        paidOn: '2026-11-03',
        method: PaymentMethod.pix,
      ),
    );

    paid.fold((_) => fail('expected to record the payment'), (operation) {
      expect(operation.summary.soldCents, 0);
      expect(operation.summary.receivedCents, 5000);
      expect(operation.sales, isEmpty);
      expect(operation.summary.receivableCents, isNull);
    });
  });
}
