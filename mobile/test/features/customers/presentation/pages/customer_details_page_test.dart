import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/usecases/address_use_cases.dart';
import 'package:pouapp/features/customers/domain/usecases/contact_use_cases.dart';
import 'package:pouapp/features/customers/domain/usecases/customer_use_cases.dart';
import 'package:pouapp/features/customers/presentation/bloc/customer_details_bloc.dart';
import 'package:pouapp/features/customers/presentation/pages/customer_details_page.dart';
import 'package:pouapp/features/workspace/domain/entities/company_operation.dart';
import 'package:pouapp/features/workspace/domain/entities/sales_board.dart';
import 'package:pouapp/features/workspace/domain/entities/stock_board.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:pouapp/features/workspace/domain/usecases/workspace_use_cases.dart';
import 'package:pouapp/features/workspace/presentation/bloc/company_operation_bloc.dart';

class MockGetCustomerById extends Mock implements GetCustomerById {}

class MockChangeCustomerStatus extends Mock implements ChangeCustomerStatus {}

class MockGetCustomerAddresses extends Mock implements GetCustomerAddresses {}

class MockAddCustomerAddress extends Mock implements AddCustomerAddress {}

class MockUpdateCustomerAddress extends Mock implements UpdateCustomerAddress {}

class MockDeleteCustomerAddress extends Mock implements DeleteCustomerAddress {}

class MockSetPrimaryCustomerAddress extends Mock
    implements SetPrimaryCustomerAddress {}

class MockGetCustomerContacts extends Mock implements GetCustomerContacts {}

class MockAddCustomerContact extends Mock implements AddCustomerContact {}

class MockUpdateCustomerContact extends Mock implements UpdateCustomerContact {}

class MockDeleteCustomerContact extends Mock implements DeleteCustomerContact {}

class MockGetCompanyOperation extends Mock implements GetCompanyOperation {}

void main() {
  late MockGetCustomerById getCustomerById;

  final customer = Customer(
    id: '1',
    type: CustomerType.individual,
    name: 'João Oliveira',
    document: '52998224725',
    phone: '21977776666',
    email: 'joao@example.com',
    status: CustomerStatus.active,
    externalSource: CustomerSource.local,
    createdAt: DateTime.utc(2026, 3, 1),
    updatedAt: DateTime.utc(2026, 3, 1),
  );

  const herOrder = SaleOrder(
    id: 'order-1042',
    code: '1042',
    customerId: '1',
    customerName: 'João Oliveira',
    lines: [
      SaleLine(
        productName: 'Banana nanica',
        quantity: 10,
        unit: SaleUnit.kilogram,
        unitPriceCents: 1864,
      ),
    ],
    recorded: true,
    delivered: false,
  );

  const someoneElse = SaleOrder(
    id: 'order-1043',
    code: '1043',
    customerId: '2',
    customerName: 'Outra cliente',
    lines: [
      SaleLine(
        productName: 'Tomate italiano',
        quantity: 4,
        unit: SaleUnit.kilogram,
        unitPriceCents: 1050,
      ),
    ],
    recorded: true,
    delivered: false,
  );

  setUp(() {
    getCustomerById = MockGetCustomerById();
    when(() => getCustomerById('1')).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return Right(customer);
    });
  });

  Future<void> pumpDetails(
    WidgetTester tester, {
    List<SaleOrder> orders = const [herOrder, someoneElse],
    Customer? person,
    Future<bool> Function(String digits)? openWhatsApp,
  }) async {
    final shown = person ?? customer;
    when(() => getCustomerById('1')).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return Right(shown);
    });
    final details = CustomerDetailsBloc(
      getCustomerById: getCustomerById,
      changeCustomerStatus: MockChangeCustomerStatus(),
      getCustomerAddresses: MockGetCustomerAddresses(),
      addCustomerAddress: MockAddCustomerAddress(),
      updateCustomerAddress: MockUpdateCustomerAddress(),
      deleteCustomerAddress: MockDeleteCustomerAddress(),
      setPrimaryCustomerAddress: MockSetPrimaryCustomerAddress(),
      getCustomerContacts: MockGetCustomerContacts(),
      addCustomerContact: MockAddCustomerContact(),
      updateCustomerContact: MockUpdateCustomerContact(),
      deleteCustomerContact: MockDeleteCustomerContact(),
    )..add(const CustomerDetailsRequested('1'));
    when(() => details.getCustomerAddresses('1'))
        .thenAnswer((_) async => const Right([]));
    when(() => details.getCustomerContacts('1'))
        .thenAnswer((_) async => const Right([]));
    final sales = CompanyOperationBloc(getOperation: MockGetCompanyOperation())
      ..add(
        CompanyOperationUpdated(
          CompanyOperation(
            summary: const SalesSummary(
              soldCents: 0,
              receivedCents: 0,
              receivableCents: 0,
              payableCents: 0,
              pendingDeliveries: 0,
            ),
            deliveries: const [],
            sales: const [],
            team: const [],
            stock: const StockSummary(
              pendingReceipts: 0,
              lowStockProducts: 0,
              movementsToday: 0,
            ),
            receipts: const [],
            products: const [
              StockProduct(
                id: 'product-banana',
                name: 'Banana nanica',
                unit: StockUnit.kilogram,
                available: 86,
                low: false,
              ),
              StockProduct(
                id: 'product-tomate',
                name: 'Tomate italiano',
                unit: StockUnit.box,
                available: 14,
                low: false,
              ),
              StockProduct(
                id: 'product-alface',
                name: 'Alface crespa',
                unit: StockUnit.piece,
                available: 40,
                low: false,
              ),
              StockProduct(
                id: 'product-laranja',
                name: 'Laranja pera',
                unit: StockUnit.kilogram,
                available: 22,
                low: true,
              ),
              StockProduct(
                id: 'product-mamao',
                name: 'Mamão formosa',
                unit: StockUnit.kilogram,
                available: 8,
                low: true,
              ),
            ],
            street: StreetLedger(orders: orders),
          ),
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: details),
            BlocProvider.value(value: sales),
          ],
          child: CustomerDetailsView(openWhatsApp: openWhatsApp),
        ),
      ),
    );
  }

  testWidgets('should show status, phone and this customer sales', (
    tester,
  ) async {
    String? opened;
    await pumpDetails(
      tester,
      openWhatsApp: (digits) async {
        opened = digits;
        return true;
      },
    );

    expect(find.bySemanticsLabel('Carregando cliente'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'João Oliveira'), findsOneWidget);
    expect(find.text('Histórico de vendas'), findsNothing);
    expect(find.text('João Oliveira'), findsWidgets);
    expect(
      tester.widget<Text>(find.byKey(const Key('customer_open_balance'))).data,
      'R\$ 0,00',
    );
    expect(find.text('Total desta nota'), findsOneWidget);
    expect(find.text('R\$ 186,40'), findsOneWidget);
    final valueTop = tester
        .getTopLeft(find.byKey(const Key('customer_note_value')))
        .dy;
    final situationTop = tester.getTopLeft(find.text('Situação')).dy;
    final dueTop = tester.getTopLeft(find.text('Vencimento')).dy;
    final itemsTop = tester.getTopLeft(find.text('Itens (0)')).dy;
    expect(situationTop, lessThan(valueTop));
    expect(valueTop, lessThan(dueTop));
    expect(dueTop, lessThan(itemsTop));
    expect(find.text('Situação'), findsOneWidget);
    expect(find.text('Rascunho'), findsOneWidget);
    expect(find.text('Aprovado'), findsNothing);
    expect(find.text('Ativo'), findsNothing);
    expect(find.text('Nenhum item nesta nota.'), findsOneWidget);
    expect(find.text('Laranja PACOTE 2KG'), findsNothing);

    await tester.tap(find.byKey(const Key('due_calendar')));
    await tester.pumpAndSettle();
    expect(find.text('Escolha a data de vencimento'), findsOneWidget);
    await tester.tap(find.byKey(const Key('due_day_15')));
    await tester.pump();
    expect(find.textContaining('15 de '), findsOneWidget);
    await tester.tap(find.byKey(const Key('due_confirm')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('customer_due_date'))).data,
      startsWith('15/'),
    );

    expect(find.text('mandar mensagem'), findsOneWidget);
    expect(find.text('Itens (0)'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Produto'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('add_item')));
    await tester.tap(find.byKey(const Key('add_item')));
    await tester.pumpAndSettle();
    expect(find.text('Produtos'), findsOneWidget);
    expect(find.text('Cadastrar novo produto'), findsOneWidget);
    expect(find.text('Alface crespa'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/produce/alface.jpg')),
      findsWidgets,
    );
    await tester.tap(find.byKey(const Key('catalog_product-alface')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_product')));
    await tester.pumpAndSettle();
    expect(find.text('Excluir Alface crespa?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_delete_product')));
    await tester.pumpAndSettle();
    expect(find.text('Alface crespa'), findsNothing);
    expect(find.text('Laranja pera'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('catalog_product-mamao')),
      300,
    );
    expect(find.text('Mamão formosa'), findsOneWidget);
    expect(find.text('SKU: MAMAO'), findsOneWidget);
    expect(find.text('Estoque: 8 kg'), findsOneWidget);
    await tester.tap(find.byKey(const Key('catalog_product-mamao')));
    await tester.pumpAndSettle();
    expect(find.text('Quantidade'), findsOneWidget);
    expect(find.text('Preço'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.image(const AssetImage('assets/produce/mamao.jpg')),
      ),
      findsOneWidget,
    );
    final price = tester.widget<TextField>(find.byKey(const Key('item_price')));
    expect(
      price.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
    expect(price.focusNode!.hasFocus, isTrue);
    await tester.enterText(find.byKey(const Key('item_price')), '5,00');
    await tester.tap(find.byKey(const Key('item_save')));
    await tester.pumpAndSettle();
    expect(find.text('Mamão formosa'), findsOneWidget);
    expect(find.text('Itens (1)'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/produce/mamao.jpg')),
      findsOneWidget,
    );
    expect(find.text('1.0 x R\$ 5,00'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('customer_open_balance'))).data,
      'R\$ 5,00',
    );

    await tester.ensureVisible(find.byKey(const Key('edit_Mamão formosa')));
    await tester.tap(find.byKey(const Key('edit_Mamão formosa')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('item_quantity_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('item_quantity_plus')));
    await tester.pump();
    expect(find.text('3,0'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('item_price')), '12,00');
    await tester.tap(find.byKey(const Key('item_save')));
    await tester.pumpAndSettle();
    expect(find.text('3.0 x R\$ 12,00'), findsOneWidget);
    expect(find.text('R\$ 36,00'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('customer_open_balance')));
    expect(
      tester.widget<Text>(find.byKey(const Key('customer_open_balance'))).data,
      'R\$ 36,00',
    );
    expect(find.text('#1042'), findsNothing);
    expect(find.text('Tomate italiano'), findsNothing);
    expect(find.text('joao@example.com'), findsNothing);
    expect(find.textContaining('529'), findsNothing);
    expect(find.text('Dados cadastrais'), findsNothing);
    expect(find.text('Endereços'), findsNothing);
    expect(find.text('Contatos'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('customer_whatsapp_order-1042')),
    );
    await tester.tap(find.byKey(const Key('customer_whatsapp_order-1042')));
    await tester.pump();
    expect(opened, '5521977776666');
    expect(find.text('Venda 1042'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('customer_sale_name_order-1042')),
    );
    await tester.tap(find.byKey(const Key('customer_sale_name_order-1042')));
    await tester.pumpAndSettle();
    expect(find.text('Venda 1042'), findsOneWidget);
    expect(find.text('Banana nanica'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/produce/banana.jpg')),
      findsOneWidget,
    );
    expect(find.text('10.0 x R\$ 18,64'), findsOneWidget);
    expect(find.text('Editar'), findsWidgets);
  });

  testWidgets('should show when the customer is inactive', (tester) async {
    final inactive = Customer(
      id: customer.id,
      type: customer.type,
      name: customer.name,
      document: customer.document,
      phone: customer.phone,
      email: customer.email,
      status: CustomerStatus.inactive,
      externalSource: customer.externalSource,
      createdAt: customer.createdAt,
      updatedAt: customer.updatedAt,
    );
    await pumpDetails(tester, person: inactive, orders: const [herOrder]);
    await tester.pumpAndSettle();

    expect(find.text('Rascunho'), findsOneWidget);
    expect(find.text('Aprovado'), findsNothing);
    expect(find.text('Cancelado'), findsNothing);
  });

  testWidgets('should say when this customer has no sales', (tester) async {
    await pumpDetails(tester, orders: const [someoneElse]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer_sales_empty')), findsOneWidget);
    expect(find.text('mandar mensagem'), findsNothing);
    expect(find.text('Tomate italiano'), findsNothing);
  });
}
