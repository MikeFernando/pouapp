import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/app/pou_app_colors.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/workspace/data/datasources/workspace_simulated_data_source.dart';
import 'package:pouapp/features/workspace/domain/entities/company_operation.dart';
import 'package:pouapp/features/workspace/domain/entities/sales_board.dart';
import 'package:pouapp/features/workspace/domain/entities/stock_board.dart';
import 'package:pouapp/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:pouapp/features/workspace/presentation/operation_labels.dart';
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

      expect(
        find.text('Visitas em ${formatDay(DateTime.now())}'),
        findsOneWidget,
      );
      expect(find.text('WhatsApp'), findsNothing);
      expect(
        find.byKey(const Key('action_new_sale')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('voice_assistant_button')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byTooltip('Assistente de voz'), findsOneWidget);
      expect(find.text('Sandy'), findsOneWidget);
      expect(find.byKey(const Key('header_month_billed')), findsOneWidget);
      expect(find.byKey(const Key('header_month_delta')), findsOneWidget);
      expect(find.textContaining('R\$'), findsWidgets);
      expect(find.text('Disponibilidade'), findsWidgets);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('visit_balance_visit-primavera')),
            )
            .data,
        'R\$ 33,60',
      );
      expect(find.text('22/10/2026'), findsNothing);
      expect(find.text('Abrir endereço'), findsNothing);
      expect(find.text('Atender'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('visit_visit-primavera')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Feito').hitTestable(), findsNothing);
      await tester.drag(
        find.byKey(const Key('visit_visit-primavera')),
        const Offset(-260, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Feito').hitTestable(), findsOneWidget);
      expect(find.text('Adiar').hitTestable(), findsOneWidget);
      expect(find.text('Remover').hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('workspace_header')), findsOneWidget);
      expect(find.text('Gestão'), findsNothing);
      expect(find.text('Resumo do mês'), findsNothing);
      expect(find.text('Financeiro'), findsNothing);
      expect(find.text('Marina Costa'), findsWidgets);
    });

    testWidgets('load matches nova venda and return is an outline', (
      tester,
    ) async {
      await signIn(tester);

      ButtonStyle styleOf(Key key) {
        return tester.widget<FilledButton>(find.byKey(key)).style!;
      }

      const idle = <WidgetState>{};
      final sale = styleOf(const Key('action_new_sale'));
      final load = styleOf(const Key('load_montana'));
      expect(load.minimumSize?.resolve(idle), sale.minimumSize?.resolve(idle));
      expect(
        load.backgroundColor?.resolve(idle),
        sale.backgroundColor?.resolve(idle),
      );
      expect(
        load.foregroundColor?.resolve(idle),
        sale.foregroundColor?.resolve(idle),
      );
      expect(load.shape?.resolve(idle), sale.shape?.resolve(idle));

      final back = tester
          .widget<OutlinedButton>(find.byKey(const Key('return_warehouse')))
          .style!;
      expect(back.backgroundColor?.resolve(idle), pouCanvas);
      expect(sale.foregroundColor?.resolve(idle), Colors.white);
      expect(back.foregroundColor?.resolve(idle), pouInk);
      expect(
        back.side?.resolve(idle)?.color,
        sale.backgroundColor?.resolve(idle),
      );
      expect(back.minimumSize?.resolve(idle), sale.minimumSize?.resolve(idle));
      expect(back.shape?.resolve(idle), sale.shape?.resolve(idle));
    });

    testWidgets('opens customer details and notes from the visit name', (
      tester,
    ) async {
      await signIn(tester);

      await tester.tap(find.byKey(const Key('visit_customer_visit-primavera')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('visit_customer_profile')), findsOneWidget);
      expect(find.text('Documento'), findsNothing);
      expect(find.text('Endereços'), findsNothing);
      expect(find.text('Contatos'), findsNothing);
      expect(find.text('(11) 98888-7777'), findsOneWidget);
      expect(find.byKey(const Key('customer_whatsapp')), findsOneWidget);
      expect(find.text('Nota 1042'), findsOneWidget);
      expect(find.textContaining('Banana nanica'), findsOneWidget);
      expect(find.text('1 kg · R\$ 5,90'), findsWidgets);
      expect(find.text('Alface crespa'), findsOneWidget);
      expect(find.text('1 maço · R\$ 3,50'), findsOneWidget);
      expect(find.text('Valor da nota'), findsWidgets);
      expect(find.text('R\$ 33,60'), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(const Key('add_visit_product')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('visit_customer_profile')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Adicionar produto'), findsOneWidget);
      expect(find.text('Batata'), findsNothing);
    });

    testWidgets('Nova venda adds a person to the delivery list', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await signIn(tester);
      await tester.tap(find.byKey(const Key('action_new_sale')));
      await tester.pumpAndSettle();

      expect(find.text('Escolha quem vai receber a entrega.'), findsOneWidget);
      expect(find.textContaining('Saldo em aberto'), findsNothing);
      final people = find.descendant(
        of: find.byKey(const Key('add_delivery_list')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('delivery_person_demo-customer-joao')),
        400,
        scrollable: people,
      );
      expect(
        find.byKey(const Key('delivery_person_demo-customer-joao')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('delivery_person_demo-customer-primavera')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('delivery_person_demo-customer-joao')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('delivery_person_demo-customer-joao')),
        findsNothing,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('João Oliveira'), findsOneWidget);
      expect(find.text('Marina Costa'), findsOneWidget);
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

      expect(find.text('Nenhuma entrega em 20/10/2026.'), findsOneWidget);
      expect(find.text('Resumo do mês'), findsNothing);
    });
  });
}
