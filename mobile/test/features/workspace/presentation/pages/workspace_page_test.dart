import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/workspace/data/datasources/workspace_simulated_data_source.dart';
import 'package:pouapp/features/workspace/domain/entities/company_operation.dart';
import 'package:pouapp/features/workspace/domain/entities/sales_board.dart';
import 'package:pouapp/features/workspace/domain/entities/stock_board.dart';
import 'package:pouapp/features/workspace/domain/entities/workspace_mode.dart';
import 'package:pouapp/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:pouapp/features/workspace/domain/rules/company_indicators.dart';
import 'package:pouapp/features/workspace/presentation/operation_labels.dart';
import 'package:pouapp/features/workspace/presentation/theme/workspace_colors.dart';
import 'package:pouapp/injection_container.dart' as di;
import 'package:pouapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockWorkspaceRepository extends Mock implements WorkspaceRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(WorkspaceMode.rua);
  });

  Future<void> signIn(WidgetTester tester) async {
    await tester.pumpWidget(const PouApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login_email')),
      'ana.souza@pouapp.dev',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'senha-dev',
    );
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

    testWidgets('should switch the home, theme and shortcuts of one company', (
      tester,
    ) async {
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
      expect(find.text('Entregas'), findsWidgets);
      expect(find.text('Disponibilidade'), findsWidgets);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('visit_balance_visit-primavera')),
            )
            .data,
        'R\$ 186,40',
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
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const Key('workspace_header')))
            .color,
        WorkspaceColors.rua.header,
      );

      await tester.tap(find.byKey(const Key('workspace_mode_gestao')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('action_finance')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('voice_assistant_button')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('action_stock')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Ajuste'), findsNothing);
      expect(find.text('Estoque'), findsOneWidget);
      await tester.tap(find.byKey(const Key('action_stock')));
      await tester.pumpAndSettle();
      expect(find.text('Buscar produto'), findsOneWidget);
      expect(
        find.byKey(const Key('voice_assistant_button')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('action_new_sale')).hitTestable(),
        findsNothing,
      );
      expect(find.text('Resumo do mês'), findsOneWidget);
      expect(find.text('Faturamento do mês'), findsOneWidget);
      expect(find.text('Já recebido'), findsOneWidget);
      expect(find.text('Falta receber'), findsOneWidget);
      expect(find.text('Vendas no mês'), findsOneWidget);
      expect(find.text('A receber hoje'), findsOneWidget);
      expect(find.text('Nenhuma venda neste mês.'), findsOneWidget);
      expect(
        find.text('Nenhum recebimento previsto para hoje.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('due_today_all')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('gestao_board_scroll')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('due_today_all')));
      await tester.pumpAndSettle();
      expect(find.text('A receber hoje'), findsWidgets);
      expect(find.text('Nenhum recebimento previsto para hoje.'), findsWidgets);
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(find.text('Registros da empresa'), findsNothing);
      expect(find.text('Estoque e Recebimento'), findsNothing);
      expect(find.text('Você pode precisar'), findsNothing);
      expect(find.text('A empresa hoje'), findsNothing);
      expect(find.text('Esse mês'), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('month_billed'))).data,
        'R\$ 0,00',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('month_received'))).data,
        'R\$ 0,00',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('month_open'))).data,
        'R\$ 0,00',
      );
      expect(find.text('R\$ 2.450,00'), findsNothing);
      expect(find.text('Maria Costa'), findsNothing);
      expect(find.text('-2 kg'), findsNothing);
      expect(find.text('Verde Vale'), findsNothing);
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const Key('workspace_header')))
            .color,
        WorkspaceColors.gestao.header,
      );

      await tester.tap(find.byKey(const Key('workspace_mode_rua')));
      await tester.pumpAndSettle();
      expect(find.text('Marina Costa'), findsWidgets);
    });

    testWidgets('load matches nova venda and return is a white outline', (
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
      final blue = sale.backgroundColor?.resolve(idle);
      expect(back.backgroundColor?.resolve(idle), Colors.white);
      expect(back.foregroundColor?.resolve(idle), blue);
      expect(back.side?.resolve(idle)?.color, blue);
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
      expect(find.text('Valor da nota'), findsWidgets);
      expect(find.text('R\$ 186,40'), findsOneWidget);
      expect(find.text('Adicionar produto'), findsOneWidget);
      expect(find.textContaining('Tomate italiano'), findsNothing);
    });

    testWidgets('should restore the last mode after a new launch', (
      tester,
    ) async {
      await signIn(tester);
      await tester.tap(find.byKey(const Key('workspace_mode_gestao')));
      await tester.pumpAndSettle();

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('workspace_mode'), 'gestao');

      await tester.pumpWidget(const PouApp());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('action_finance')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const Key('workspace_header')))
            .color,
        WorkspaceColors.gestao.header,
      );
    });

    testWidgets('should open a provisional action without saving', (
      tester,
    ) async {
      await signIn(tester);
      await tester.tap(find.byKey(const Key('workspace_mode_gestao')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('action_sales')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('provisional_notice')), findsOneWidget);
      expect(find.text('Nada foi salvo.'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('Resumo do mês'), findsOneWidget);
      expect(find.text('Verde Vale'), findsNothing);
      expect(find.text('Ceasa Campinas'), findsNothing);
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

    testWidgets('should open financeiro where recebimento was', (tester) async {
      await signIn(tester);

      expect(find.text('Recebimento'), findsOneWidget);
      expect(find.text('Financeiro'), findsNothing);
      await tester.tap(find.byKey(const Key('workspace_mode_gestao')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('action_finance')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('finance_title')), findsOneWidget);
      expect(find.text('Extrato de movimentações'), findsOneWidget);
      expect(find.text('Fluxo de caixa diário'), findsOneWidget);
      expect(find.text('Conciliações pendentes'), findsOneWidget);
      expect(find.textContaining('Visitas em').hitTestable(), findsNothing);

      await tester.tap(find.text('Extrato de movimentações'));
      await tester.pumpAndSettle();

      expect(find.text('Movimentações'), findsOneWidget);
      expect(find.text('Receitas em aberto'), findsOneWidget);
      expect(find.text('Vendido registrado'), findsOneWidget);
      expect(find.text('Todos os registros'), findsWidgets);
      expect(
        find.text('Filtro por mês indisponível: vendas antigas não têm data.'),
        findsOneWidget,
      );
      expect(find.text('Esse mês'), findsNothing);
      expect(find.text('Contas: Todas'), findsNothing);
      expect(find.text('Total do período'), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('movements_open'))).data,
        'R\$ 0,00',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('movements_total'))).data,
        'R\$ 0,00',
      );
      expect(find.text('Marina Costa'), findsNothing);
      expect(find.text('Venda 1042'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Nenhum lançamento registrado.'),
        200,
      );
      expect(find.text('Nenhum lançamento registrado.'), findsOneWidget);

      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fluxo de caixa diário'));
      await tester.pumpAndSettle();

      expect(find.text(receiptsInMonthLabel(DateTime.now())), findsOneWidget);
      expect(find.text('Pagamentos'), findsWidgets);
      expect(find.text('Saldo'), findsWidgets);
      expect(
        tester.widget<Text>(find.byKey(const Key('cash_flow_receipts'))).data,
        'R\$ 0,00',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('cash_flow_payments'))).data,
        'Ainda não disponível',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('cash_flow_balance'))).data,
        'Ainda não disponível',
      );
      expect(find.text('R\$ 72,00'), findsNothing);

      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(find.text('Resumo do mês'), findsOneWidget);
      expect(
        find.byKey(const Key('action_finance')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('should lay out both modes on a small screen', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await signIn(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('workspace_mode_gestao')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('action_finance')).hitTestable(),
        findsOneWidget,
      );
    });
  });

  group('repository double', () {
    late MockWorkspaceRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await di.init();
      repository = MockWorkspaceRepository();
      when(() => repository.getMode())
          .thenAnswer((_) async => const Right(WorkspaceMode.rua));
      when(() => repository.saveMode(any()))
          .thenAnswer((_) async => const Right(unit));
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

    testWidgets('should load the company once when the mode changes', (
      tester,
    ) async {
      await signIn(tester);
      await tester.tap(find.byKey(const Key('workspace_mode_gestao')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace_mode_rua')));
      await tester.pumpAndSettle();

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

      await tester.tap(find.byKey(const Key('workspace_mode_gestao')));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma venda neste mês.'), findsOneWidget);
      expect(
        find.text('Nenhum recebimento previsto para hoje.'),
        findsOneWidget,
      );
      expect(find.text('Nenhum recebimento.'), findsNothing);
      expect(find.text('Nenhuma pendência da equipe.'), findsNothing);
      expect(find.text('Nenhuma divergência.'), findsNothing);
    });
  });
}
