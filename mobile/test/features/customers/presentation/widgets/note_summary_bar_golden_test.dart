import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/customers/domain/entities/customer.dart';
import 'package:pouapp/features/customers/domain/entities/customer_note.dart';
import 'package:pouapp/features/customers/presentation/widgets/note_summary_bar.dart';
import 'package:pouapp/features/workspace/domain/entities/street_ledger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('note summary bar matches reference content', (tester) async {
    final customer = Customer(
      id: 'c1',
      type: CustomerType.individual,
      name: 'Cliente',
      status: CustomerStatus.active,
      externalSource: CustomerSource.local,
      createdAt: DateTime.utc(2026, 11, 12),
      updatedAt: DateTime.utc(2026, 11, 12),
    );
    final now = DateTime.utc(2026, 11, 12);
    final note = CustomerNote(
      id: 'n1',
      customerId: customer.id,
      status: NoteStatus.draft,
      createdAt: now,
      updatedAt: now,
      dueOn: DateTime(2026, 11, 12),
      lines: const [
        NoteLine(
          id: 'l1',
          productId: 'p1',
          name: 'A',
          unit: CatalogUnit.piece,
          quantity: 1,
          unitPriceCents: 100,
        ),
        NoteLine(
          id: 'l2',
          productId: 'p2',
          name: 'B',
          unit: CatalogUnit.piece,
          quantity: 1,
          unitPriceCents: 100,
        ),
        NoteLine(
          id: 'l3',
          productId: 'p3',
          name: 'C',
          unit: CatalogUnit.piece,
          quantity: 1,
          unitPriceCents: 100,
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(390, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFF6F5F7),
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(bottom: 34),
              ),
              child: NoteSummaryBar(
                customer: customer,
                note: note,
                paymentMethod: PaymentMethod.pix,
                onPickPayment: () {},
                onPickDue: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('R\$ 3,00'), findsOneWidget);
    expect(find.text('Pix'), findsOneWidget);
    expect(find.text('VENCIMENTO'), findsOneWidget);
    expect(find.text('12/11/2026'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
    expect(find.byKey(const Key('note_summary_bar')), findsOneWidget);
    expect(find.byKey(const Key('receive_payment')), findsOneWidget);
    expect(find.byKey(const Key('note_summary_due')), findsOneWidget);
    expect(find.byKey(const Key('note_summary_payment')), findsOneWidget);

    await expectLater(
      find.byKey(const Key('note_summary_bar')),
      matchesGoldenFile('goldens/note_summary_bar.png'),
    );
  }, tags: ['golden']);
}
