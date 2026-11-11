import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/catalog/domain/entities/catalog.dart';
import 'package:pouapp/features/customers/data/note_pdf_document.dart';
import 'package:pouapp/features/customers/domain/entities/customer_note.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('noteLineQuantityPriceLabel', () {
    test('formats piece with multiplication sign and BRL', () {
      const line = NoteLine(
        id: '1',
        name: 'Banana prata',
        unit: CatalogUnit.piece,
        quantity: 1,
        unitPriceCents: 690,
      );
      expect(noteLineQuantityPriceLabel(line), '1 × R\$ 6,90');
    });

    test('formats kilogram with unit', () {
      const line = NoteLine(
        id: '2',
        name: 'Cebola',
        unit: CatalogUnit.kilogram,
        quantity: 1500,
        unitPriceCents: 450,
      );
      expect(noteLineQuantityPriceLabel(line), '1,5 kg × R\$ 4,50');
    });
  });

  group('NotePdfSnapshot.fromNote', () {
    test('purchase date is the day items were added (updatedAt)', () {
      final created = DateTime(2026, 11, 10, 9);
      final updated = DateTime(2026, 11, 11, 15, 30);
      final note = CustomerNote(
        id: 'n1',
        customerId: 'c1',
        status: NoteStatus.draft,
        createdAt: created,
        updatedAt: updated,
        dueOn: DateTime(2026, 11, 30),
        lines: const [
          NoteLine(
            id: 'l1',
            name: 'Abacate',
            unit: CatalogUnit.piece,
            quantity: 1,
            unitPriceCents: 890,
          ),
        ],
      );
      final snap = NotePdfSnapshot.fromNote(
        customerName: 'Mike Fernando',
        note: note,
        imagesByProductName: const {},
      );
      expect(snap.purchaseDate, DateTime(2026, 11, 11));
      expect(snap.isDraft, isTrue);
      expect(snap.noteTotalCents, 890);
      expect(snap.lines.single.quantityPriceLabel, '1 × R\$ 8,90');
    });

    test('empty note has no purchase date', () {
      final now = DateTime(2026, 11, 11);
      final note = CustomerNote(
        id: 'n2',
        customerId: 'c1',
        status: NoteStatus.draft,
        createdAt: now,
        updatedAt: now,
        lines: const [],
      );
      final snap = NotePdfSnapshot.fromNote(
        customerName: 'Sueli',
        note: note,
        imagesByProductName: const {},
      );
      expect(snap.purchaseDate, isNull);
    });
  });

  group('NotePdfDocument.build', () {
    test('builds reference scenario PDF bytes', () async {
      final images = <String, Uint8List?>{
        'Banana prata': await _assetBytes('assets/produce/banana.jpg'),
        'Abacate': await _assetBytes('assets/produce/abacate.jpg'),
        'Pêssego': await _assetBytes('assets/produce/pessego.jpg'),
      };
      final note = CustomerNote(
        id: 'ref',
        customerId: 'c',
        status: NoteStatus.draft,
        createdAt: DateTime(2026, 11, 11),
        updatedAt: DateTime(2026, 11, 11),
        dueOn: DateTime(2026, 11, 30),
        lines: const [
          NoteLine(
            id: '1',
            name: 'Banana prata',
            unit: CatalogUnit.piece,
            quantity: 1,
            unitPriceCents: 690,
          ),
          NoteLine(
            id: '2',
            name: 'Abacate',
            unit: CatalogUnit.piece,
            quantity: 1,
            unitPriceCents: 890,
          ),
          NoteLine(
            id: '3',
            name: 'Pêssego',
            unit: CatalogUnit.piece,
            quantity: 1,
            unitPriceCents: 1290,
          ),
        ],
      );
      expect(note.totalCents, 2870);

      final snapshot = NotePdfSnapshot.fromNote(
        customerName: 'Mike Fernando',
        note: note,
        imagesByProductName: images,
      );
      final doc = await NotePdfDocument.loadAssets();
      final bytes = await doc.build(snapshot);
      expect(bytes.length, greaterThan(1000));
      expect(bytes[0], 0x25); // %
      expect(bytes[1], 0x50); // P
      expect(bytes[2], 0x44); // D
      expect(bytes[3], 0x46); // F

      final out = File(
        '${Directory.systemTemp.path}/pouapp_nota_exemplo.pdf',
      );
      await out.writeAsBytes(bytes);
      // Also copy next to mobile/ for review when run locally.
      final review = File('artifacts/pouapp_nota_exemplo.pdf');
      await review.parent.create(recursive: true);
      await review.writeAsBytes(bytes);
      expect(await review.exists(), isTrue);
    });

    test('builds long note across pages and missing image', () async {
      final lines = <NoteLine>[
        for (var i = 0; i < 18; i++)
          NoteLine(
            id: 'long-$i',
            name: i == 0
                ? 'Produto sem foto XYZ'
                : 'Banana prata premium seleção especial $i',
            unit: CatalogUnit.piece,
            quantity: 1 + (i % 3),
            unitPriceCents: 690 + i * 10,
          ),
      ];
      final note = CustomerNote(
        id: 'long',
        customerId: 'c',
        status: NoteStatus.delivered,
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
        dueOn: DateTime(2026, 11, 30),
        lines: lines,
      );
      final images = <String, Uint8List?>{
        for (final line in lines)
          line.name: line.name.contains('sem foto')
              ? null
              : await _assetBytes('assets/produce/banana.jpg'),
      };
      final snapshot = NotePdfSnapshot.fromNote(
        customerName: 'Cliente com nome bem longo para testar quebra',
        note: note,
        imagesByProductName: images,
        openBalanceCents: note.totalCents ~/ 2,
      );
      final doc = await NotePdfDocument.loadAssets();
      final bytes = await doc.build(snapshot);
      expect(bytes.length, greaterThan(2000));
    });
  });
}

Future<Uint8List> _assetBytes(String asset) async {
  final data = await rootBundle.load(asset);
  return data.buffer.asUint8List();
}
