import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/workspace/data/datasources/workspace_simulated_data_source.dart';
import 'package:pouapp/features/workspace/domain/entities/company_operation.dart';
import 'package:pouapp/features/workspace/domain/entities/sales_board.dart';
import 'package:pouapp/features/workspace/domain/entities/stock_board.dart';
import 'package:pouapp/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:pouapp/injection_container.dart' as di;
import 'package:pouapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockWorkspaceRepository extends Mock implements WorkspaceRepository {}

void main() {
  Future<void> signIn(WidgetTester tester) async {
    await tester.pumpWidget(const PouApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login_email')),
      'mike@gmail.com',
    );
    await tester.enterText(find.byKey(const Key('login_password')), 'mike@123');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  group('simulated operation', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await di.init();
    });

    tearDown(() async {
      if (di.sl.isRegistered<CatalogLocalDataSource>()) {
        await di.sl<CatalogLocalDataSource>().close();
      }
      await di.sl.reset();
    });

    testWidgets('should open the deliveries workspace', (tester) async {
      await signIn(tester);

      expect(find.text('Recebimentos do dia'), findsOneWidget);
      expect(find.text('Próximos vencimentos'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('action_new_sale')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('action_new_sale')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const Key('voice_assistant_button')), findsNothing);
      expect(find.byTooltip('Assistente de voz'), findsNothing);
      expect(find.text('Sandy'), findsOneWidget);
      expect(find.text('Faturado'), findsNothing);
      expect(find.textContaining('Em aberto'), findsNothing);
      expect(find.byKey(const Key('header_month_billed')), findsNothing);
      expect(find.byKey(const Key('header_month_delta')), findsNothing);
      expect(find.textContaining('R\$'), findsWidgets);
      expect(find.text('Abrir endereço'), findsNothing);
      expect(find.text('Atender'), findsNothing);
      expect(find.byKey(const Key('workspace_header')), findsOneWidget);
      expect(find.text('Gestão'), findsNothing);
      expect(find.text('Resumo do mês'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Produtos'), findsOneWidget);
      expect(find.text('Clientes'), findsOneWidget);
      expect(find.text('Financeiro'), findsOneWidget);
    });

    testWidgets('Nova venda opens the delivery picker', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await signIn(tester);
      await tester.tap(find.byKey(const Key('action_new_sale')));
      await tester.pumpAndSettle();

      expect(find.text('Escolha quem vai receber a entrega.'), findsOneWidget);
      expect(find.byKey(const Key('add_delivery_list')), findsOneWidget);

      await tester.tap(find.byKey(const Key('close_add_delivery')));
      await tester.pumpAndSettle();

      expect(find.text('Recebimentos do dia'), findsOneWidget);
    });

    testWidgets('should lay out deliveries on a small screen', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await signIn(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Sandy'), findsOneWidget);
      expect(find.byKey(const Key('action_new_sale')), findsOneWidget);
    });
  });

  group('repository double', () {
    late MockWorkspaceRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await di.init();
      repository = MockWorkspaceRepository();
      when(() => repository.getOperation()).thenAnswer(
        (_) async => Right(WorkspaceSimulatedDataSource().operation()),
      );
      await di.sl.unregister<WorkspaceRepository>();
      di.sl.registerSingleton<WorkspaceRepository>(repository);
    });

    tearDown(() async {
      if (di.sl.isRegistered<CatalogLocalDataSource>()) {
        await di.sl<CatalogLocalDataSource>().close();
      }
      await di.sl.reset();
    });

    testWidgets('should load the company once', (tester) async {
      await signIn(tester);

      verify(() => repository.getOperation()).called(1);
    });

    testWidgets('should show empty lists', (tester) async {
      when(() => repository.getOperation()).thenAnswer(
        (_) async => const Right(
          CompanyOperation(
            summary: SalesSummary(
              soldCents: 0,
              receivedCents: 0,
              receivableCents: 0,
              payableCents: 0,
              pendingDeliveries: 0,
            ),
            deliveries: [],
            sales: [],
            team: [],
            stock: StockSummary(
              pendingReceipts: 0,
              lowStockProducts: 0,
              movementsToday: 0,
            ),
            receipts: [],
            products: [],
          ),
        ),
      );

      await signIn(tester);

      expect(
        find.text('Nenhum recebimento com vencimento hoje.'),
        findsOneWidget,
      );
      expect(find.text('Recebimentos do dia'), findsOneWidget);
      expect(find.text('Resumo do mês'), findsNothing);
    });
  });
}
