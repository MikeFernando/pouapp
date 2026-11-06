import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pouapp/features/catalog/data/datasources/catalog_local_data_source.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:pouapp/features/workspace/data/receivable_store.dart';
import 'package:pouapp/features/workspace/domain/entities/receivable.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';
import 'package:pouapp/features/workspace/presentation/pages/charge_page.dart';
import 'package:pouapp/features/workspace/presentation/pages/receipt_page.dart';
import 'package:pouapp/injection_container.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockCustomerRepository extends Mock implements CustomerRepository {}

void main() {
  late CatalogLocalDataSourceImpl dataSource;
  late ReceivableStore store;
  late MockCustomerRepository customers;
  var ids = 0;

  setUp(() async {
    ids = 0;
    await sl.reset();
    dataSource = CatalogLocalDataSourceImpl(
      databasePath: inMemoryDatabasePath,
      seedDemo: false,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'catalog-${ids++}',
    );
    store = ReceivableStore(
      openDatabase: dataSource.database,
      clock: () => DateTime(2026, 11, 3, 12),
      newId: () => 'new-${ids++}',
    );
    customers = MockCustomerRepository();
    sl.registerSingleton<ReceivableStore>(store);
    sl.registerSingleton<CustomerRepository>(customers);
  });

  tearDown(() async {
    await dataSource.close();
    await sl.reset();
  });

  Customer person(String id, String name, {String? phone}) {
    return Customer(
      id: id,
      type: CustomerType.individual,
      name: name,
      status: CustomerStatus.active,
      externalSource: CustomerSource.local,
      createdAt: DateTime(2026, 11, 3),
      updatedAt: DateTime(2026, 11, 3),
      mobilePhone: phone,
    );
  }

  void stub(Customer customer) {
    when(() => customers.getCustomerById(customer.id))
        .thenAnswer((_) async => Right(customer));
  }

  Future<void> show(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  testWidgets('cash receipt shows the remaining balance before saving', (
    tester,
  ) async {
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 15000);
    await show(
      tester,
      const ReceiptPage(customerId: 'ana', customerName: 'Ana Souza'),
    );

    expect(find.text('Saldo anterior R\$ 150,00'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('receipt_amount')), '50,00');
    await tester.pump();

    expect(find.byKey(const Key('receipt_received')), findsOneWidget);
    expect(find.textContaining('R\$ 50,00'), findsWidgets);
    expect(find.text('Saldo restante R\$ 100,00'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('receipt_save')));
    await tester.tap(find.byKey(const Key('receipt_save')));
    await tester.pumpAndSettle();

    expect((await store.account('ana')).balanceCents, 10000);
    final again = await store.confirmReceipt(
      id: 'new-0',
      customerId: 'ana',
      amountCents: 5000,
      paidOn: '2026-11-03',
      method: PaymentMethod.cash,
      receivableIds: const ['debt-ana'],
    );
    expect(again.alreadyRecorded, isTrue);
    expect((await store.account('ana')).balanceCents, 10000);
  });

  testWidgets('change of 20 is shown and is not recorded as credit', (
    tester,
  ) async {
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 8000);
    await show(
      tester,
      const ReceiptPage(customerId: 'ana', customerName: 'Ana Souza'),
    );
    await tester.enterText(find.byKey(const Key('receipt_amount')), '80,00');
    await tester.enterText(find.byKey(const Key('receipt_tendered')), '100,00');
    await tester.pump();

    expect(find.text('Troco R\$ 20,00'), findsOneWidget);
    expect(find.text('Saldo restante R\$ 0,00'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('receipt_save')));
    await tester.tap(find.byKey(const Key('receipt_save')));
    await tester.pumpAndSettle();

    final receipt = (await store.account('ana')).receipts.single;
    expect(receipt.amountCents, 8000);
    expect(receipt.changeCents, 2000);
    expect(receipt.creditCents, 0);
    expect(receipt.method, PaymentMethod.cash);
  });

  testWidgets('each charge preview belongs to one customer', (tester) async {
    await store.saveProfile(
      const BusinessProfile(
        pixKeyType: PixKeyType.phone,
        pixKey: '11988887777',
        receiverName: 'Hortifruti da Ana',
      ),
    );
    await store.openDebt(
      id: 'debt-ana',
      customerId: 'ana',
      amountCents: 15000,
      dueOn: '2026-11-10',
    );
    await store.openDebt(
      id: 'debt-bia',
      customerId: 'bia',
      amountCents: 8000,
      dueOn: '2026-12-01',
    );
    stub(person('ana', 'Ana Souza', phone: '11988887777'));
    stub(person('bia', 'Beatriz Nunes', phone: '11977776666'));

    await show(tester, const ChargePage(customerId: 'ana'));
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Beatriz Nunes'), findsNothing);
    expect(find.textContaining('R\$ 150,00'), findsWidgets);
    expect(find.textContaining('R\$ 80,00'), findsNothing);
    final anaPreview = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('charge_preview')),
        matching: find.byType(Text),
      ),
    );
    expect(anaPreview.data, contains('Olá, Ana Souza!'));
    expect(anaPreview.data, isNot(contains('Beatriz')));

    await show(tester, const ChargePage(customerId: 'bia'));
    final biaPreview = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('charge_preview')),
        matching: find.byType(Text),
      ),
    );
    expect(biaPreview.data, contains('Olá, Beatriz Nunes!'));
    expect(biaPreview.data, contains('R\$ 80,00'));
    expect(biaPreview.data, isNot(contains('Ana Souza')));
    expect(await store.netReceivedCents(), 0);
  });

  testWidgets('the message uses the balance left after a partial payment', (
    tester,
  ) async {
    await store.saveProfile(
      const BusinessProfile(
        pixKeyType: PixKeyType.email,
        pixKey: 'ana@hortifruti.com',
        receiverName: 'Hortifruti da Ana',
      ),
    );
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 15000);
    await store.confirmReceipt(
      id: 'pay-ana',
      customerId: 'ana',
      amountCents: 5000,
      paidOn: '2026-11-03',
      method: PaymentMethod.cash,
      receivableIds: const ['debt-ana'],
    );
    stub(person('ana', 'Ana Souza', phone: '11988887777'));

    await show(tester, const ChargePage(customerId: 'ana'));
    final preview = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('charge_preview')),
        matching: find.byType(Text),
      ),
    );
    expect(preview.data, contains('R\$ 100,00'));
    expect(preview.data, isNot(contains('R\$ 150,00')));
    expect((await store.account('ana')).balanceCents, 10000);
  });

  testWidgets('mixed due dates are named as the open balance', (tester) async {
    await store.saveProfile(
      const BusinessProfile(
        pixKeyType: PixKeyType.random,
        pixKey: 'chave-aleatoria-123',
        receiverName: 'Hortifruti da Ana',
      ),
    );
    await store.openDebt(
      id: 'debt-1',
      customerId: 'ana',
      amountCents: 5000,
      description: 'Nota 1',
      dueOn: '2026-11-10',
    );
    await store.openDebt(
      id: 'debt-2',
      customerId: 'ana',
      amountCents: 3000,
      description: 'Nota 2',
      dueOn: '2026-12-01',
    );
    stub(person('ana', 'Ana Souza', phone: '11988887777'));

    await show(tester, const ChargePage(customerId: 'ana'));
    await tester.tap(find.byKey(const Key('charge_total')));
    await tester.pump();
    final preview = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('charge_preview')),
        matching: find.byType(Text),
      ),
    );
    expect(preview.data, contains('do saldo em aberto'));
    expect(preview.data, contains('R\$ 80,00'));
    expect(preview.data, isNot(contains('Vencimento:')));
  });

  testWidgets('missing phone or pix key offers to complete the record', (
    tester,
  ) async {
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 15000);
    stub(person('ana', 'Ana Souza'));

    await show(tester, const ChargePage(customerId: 'ana'));
    expect(find.byKey(const Key('charge_fix_phone')), findsOneWidget);
    expect(find.byKey(const Key('charge_fix_key')), findsOneWidget);
    expect(find.byKey(const Key('charge_preview')), findsNothing);
    final open = tester.widget<FilledButton>(
      find.byKey(const Key('charge_open_whatsapp')),
    );
    expect(open.onPressed, isNull);
  });

  testWidgets('a failed whatsapp open keeps the preview and the debt', (
    tester,
  ) async {
    await store.saveProfile(
      const BusinessProfile(
        pixKeyType: PixKeyType.phone,
        pixKey: '11988887777',
        receiverName: 'Hortifruti da Ana',
      ),
    );
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 15000);
    stub(person('ana', 'Ana Souza', phone: '11988887777'));

    await show(
      tester,
      ChargePage(customerId: 'ana', openChat: (_) async => false),
    );
    expect(find.byKey(const Key('charge_preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('charge_open_whatsapp')));
    await tester.pumpAndSettle();

    expect(find.text('Cobrança preparada'), findsOneWidget);
    expect(
      find.textContaining('Não foi possível abrir o WhatsApp'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('charge_preview')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('charge_copy_message')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('charge_copy_key')))
          .onPressed,
      isNotNull,
    );
    expect((await store.account('ana')).balanceCents, 15000);
    expect(await store.netReceivedCents(), 0);
    expect(
      (await store.account('ana')).charges.single.status,
      ChargeStatus.prepared,
    );
  });

  testWidgets('opening whatsapp does not send, pay or duplicate the charge', (
    tester,
  ) async {
    await store.saveProfile(
      const BusinessProfile(
        pixKeyType: PixKeyType.phone,
        pixKey: '11988887777',
        receiverName: 'Hortifruti da Ana',
      ),
    );
    await store.openDebt(id: 'debt-ana', customerId: 'ana', amountCents: 15000);
    stub(person('ana', 'Ana Souza', phone: '11988887777'));
    var opened = 0;

    await show(
      tester,
      ChargePage(
        customerId: 'ana',
        openChat: (_) async {
          opened += 1;
          return true;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('charge_open_whatsapp')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('charge_open_whatsapp')));
    await tester.pumpAndSettle();

    expect(opened, 2);
    expect(find.text('WhatsApp aberto'), findsOneWidget);
    expect((await store.account('ana')).charges, hasLength(1));
    expect(
      (await store.account('ana')).charges.single.status,
      ChargeStatus.whatsappOpened,
    );
    expect((await store.account('ana')).balanceCents, 15000);
    expect(await store.netReceivedCents(), 0);
  });
}
