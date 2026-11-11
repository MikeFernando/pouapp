import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/customers/domain/entities/customer_note.dart';
import 'package:pouapp/features/customers/presentation/widgets/deleted_notes_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final note = CustomerNote(
    id: 'deleted-1',
    customerId: 'cust-sueli',
    status: NoteStatus.deleted,
    createdAt: DateTime(2026, 11, 11, 10),
    updatedAt: DateTime(2026, 11, 11, 15, 30),
    lines: const [
      NoteLine(
        id: 'l1',
        productId: 'abobrinha',
        name: 'Abobrinha',
        unit: CatalogUnit.piece,
        quantity: 1,
        unitPriceCents: 490,
      ),
      NoteLine(
        id: 'l2',
        productId: 'abobora',
        name: 'Abóbora',
        unit: CatalogUnit.piece,
        quantity: 2,
        unitPriceCents: 390,
      ),
    ],
  );

  test('formats deleted note day and quantity like the reference', () {
    expect(formatDeletedNoteDay(DateTime(2026, 11, 11)), '11 nov. 2026');
    expect(
      formatDeletedNoteQuantity(
        const NoteLine(
          id: '1',
          name: 'Abobrinha',
          unit: CatalogUnit.piece,
          quantity: 1,
          unitPriceCents: 490,
        ),
      ),
      '1',
    );
    expect(
      formatDeletedNoteQuantity(
        const NoteLine(
          id: '2',
          name: 'Alho',
          unit: CatalogUnit.kilogram,
          quantity: 1500,
          unitPriceCents: 1000,
        ),
      ),
      '1,5',
    );
  });

  testWidgets('renders collapsed then expanded items and captures a print', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF2F3A34),
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RepaintBoundary(
              key: const Key('deleted_notes_capture'),
              child: SizedBox(
                width: 390,
                child: Material(
                  color: const Color(0xFFF5F6F5),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: DeletedNotesSheet(
                    customerName: 'Sueli Garcez',
                    notes: [note],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notas excluídas'), findsOneWidget);
    expect(find.text('Sueli Garcez'), findsOneWidget);
    expect(find.text('11 nov. 2026'), findsOneWidget);
    expect(find.text('2 itens'), findsOneWidget);
    expect(find.text('R\$ 12,70'), findsOneWidget);
    expect(find.text('Abobrinha'), findsNothing);

    await tester.tap(find.text('11 nov. 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Abobrinha'), findsOneWidget);
    expect(find.text('Abóbora'), findsOneWidget);
    expect(find.text('1 × R\$ 4,90'), findsOneWidget);
    expect(find.text('2 × R\$ 3,90'), findsOneWidget);
    expect(find.text('R\$ 4,90'), findsWidgets);
    expect(find.text('R\$ 7,80'), findsOneWidget);
    // Total stays only in the header (plus line subtotals elsewhere).
    expect(find.text('Total dos itens'), findsNothing);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('deleted_notes_capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final out = File(
        'test/features/customers/presentation/widgets/deleted_notes_sheet_capture.png',
      );
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
    });
  });
}
