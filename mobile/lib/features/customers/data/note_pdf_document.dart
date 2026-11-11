import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../catalog/domain/entities/catalog.dart';
import '../../catalog/presentation/produce_assets.dart';
import '../../workspace/presentation/operation_labels.dart';
import '../domain/entities/customer_note.dart';
import '../domain/rules/note_rules.dart';

/// Forest green from the note PDF reference / PouApp brand.
const PdfColor notePdfForest = PdfColor.fromInt(0xFF24623A);
const PdfColor notePdfForestSoft = PdfColor.fromInt(0xFF9BBFA8);
const PdfColor notePdfWarm = PdfColor.fromInt(0xFFF7F4EF);
const PdfColor notePdfInk = PdfColor.fromInt(0xFF0E0D0F);
const PdfColor notePdfMuted = PdfColor.fromInt(0xFF5C6B61);
const PdfColor notePdfPhotoBg = PdfColor.fromInt(0xFFE9E8EB);

class NotePdfLineView {
  const NotePdfLineView({
    required this.name,
    required this.quantityPriceLabel,
    required this.totalCents,
    this.imageBytes,
  });

  final String name;
  final String quantityPriceLabel;
  final int totalCents;
  final Uint8List? imageBytes;
}

class NotePdfSnapshot {
  const NotePdfSnapshot({
    required this.customerName,
    required this.lines,
    required this.noteTotalCents,
    required this.isDraft,
    this.purchaseDate,
    this.dueOn,
    this.openBalanceCents,
  });

  final String customerName;
  final DateTime? purchaseDate;
  final DateTime? dueOn;
  final List<NotePdfLineView> lines;
  final int noteTotalCents;
  final int? openBalanceCents;
  final bool isDraft;

  factory NotePdfSnapshot.fromNote({
    required String customerName,
    required CustomerNote note,
    required Map<String, Uint8List?> imagesByProductName,
    int? openBalanceCents,
  }) {
    // Purchase date = day the items were put on the note (updated when lines change).
    final purchaseDay = note.lines.isEmpty
        ? null
        : DateTime(
            note.updatedAt.year,
            note.updatedAt.month,
            note.updatedAt.day,
          );
    return NotePdfSnapshot(
      customerName: customerName,
      purchaseDate: purchaseDay,
      dueOn: note.dueOn,
      noteTotalCents: note.totalCents,
      openBalanceCents: openBalanceCents,
      isDraft: note.status == NoteStatus.draft,
      lines: [
        for (final line in note.lines)
          NotePdfLineView(
            name: line.name,
            quantityPriceLabel: noteLineQuantityPriceLabel(line),
            totalCents: line.totalCents,
            imageBytes: imagesByProductName[line.name],
          ),
      ],
    );
  }
}

String noteLineQuantityPriceLabel(NoteLine line) {
  final qty = formatNotePdfQuantity(line.unit, line.quantity);
  return '$qty × ${formatBrl(line.unitPriceCents)}';
}

String formatNotePdfQuantity(CatalogUnit unit, int quantity) {
  final display = displayQuantity(unit, quantity);
  if (unit == CatalogUnit.kilogram) {
    final text = display == display.roundToDouble()
        ? display.toStringAsFixed(0)
        : display
            .toStringAsFixed(3)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '')
            .replaceAll('.', ',');
    return '$text kg';
  }
  final whole = display.round();
  return switch (unit) {
    CatalogUnit.dozen => whole == 1 ? '1 dúzia' : '$whole dúzias',
    CatalogUnit.box => whole == 1 ? '1 cx' : '$whole cx',
    CatalogUnit.bunch => whole == 1 ? '1 maço' : '$whole maços',
    CatalogUnit.piece => '$whole',
    CatalogUnit.kilogram => '$whole',
  };
}

String notePdfDayLabel(DateTime? date, {required String empty}) {
  if (date == null) return empty;
  return formatDay(date);
}

/// Loads produce asset bytes using the same resolver as the catalog UI.
Future<Uint8List?> loadProduceImageBytes(String productName) async {
  final asset = produceAsset(productName);
  if (asset == null) return null;
  try {
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

Future<Map<String, Uint8List?>> loadProduceImagesForLines(
  Iterable<NoteLine> lines,
) async {
  final unique = <String>{for (final line in lines) line.name};
  final out = <String, Uint8List?>{};
  for (final name in unique) {
    out[name] = await loadProduceImageBytes(name);
  }
  return out;
}

class NotePdfDocument {
  NotePdfDocument._({
    required this.regular,
    required this.bold,
    required this.logo,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.ImageProvider? logo;

  static Future<NotePdfDocument> loadAssets() async {
    final regularData = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    pw.ImageProvider? logo;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}
    return NotePdfDocument._(
      regular: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
      logo: logo,
    );
  }

  Future<Uint8List> build(NotePdfSnapshot snapshot) async {
    final doc = pw.Document(
      title: 'Resumo da compra — ${snapshot.customerName}',
      author: 'PouApp',
    );
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          theme: theme,
          buildBackground: (context) => pw.Container(color: notePdfWarm),
        ),
        header: (context) => _header(),
        build: (context) => [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  snapshot.customerName,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 26,
                    color: notePdfForest,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _infoBox(
                        title: 'Data da compra',
                        value: notePdfDayLabel(
                          snapshot.purchaseDate,
                          empty: '—',
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: _infoBox(
                        title: 'Vencimento',
                        value: notePdfDayLabel(
                          snapshot.dueOn,
                          empty: 'Sem vencimento',
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 22),
                pw.Text(
                  'Produtos comprados',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 16,
                    color: notePdfForest,
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
            ),
          ),
          for (var i = 0; i < snapshot.lines.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 28),
              child: pw.Column(
                children: [
                  if (i > 0)
                    pw.Divider(
                      color: notePdfForestSoft,
                      thickness: 0.6,
                      height: 1,
                    ),
                  _productRow(snapshot.lines[i]),
                ],
              ),
            ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 28),
            child: _totals(snapshot),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header() {
    return pw.Container(
      height: 96,
      color: notePdfForest,
      padding: const pw.EdgeInsets.fromLTRB(28, 22, 28, 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              if (logo != null) ...[
                pw.Container(
                  width: 22,
                  height: 22,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Image(logo!, fit: pw.BoxFit.contain),
                  ),
                ),
                pw.SizedBox(width: 8),
              ],
              pw.Text(
                'PouApp',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 18,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Resumo da compra',
            style: pw.TextStyle(
              font: bold,
              fontSize: 15,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _infoBox({required String title, required String value}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: notePdfForestSoft, width: 1),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: regular,
              fontSize: 10,
              color: notePdfMuted,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: bold,
              fontSize: 13,
              color: notePdfInk,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _productRow(NotePdfLineView line) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 48,
            height: 48,
            decoration: pw.BoxDecoration(
              color: notePdfPhotoBg,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            alignment: pw.Alignment.center,
            child: line.imageBytes == null
                ? pw.Container(
                    width: 18,
                    height: 18,
                    decoration: pw.BoxDecoration(
                      color: notePdfForestSoft,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                  )
                : pw.ClipRRect(
                    horizontalRadius: 10,
                    verticalRadius: 10,
                    child: pw.Image(
                      pw.MemoryImage(line.imageBytes!),
                      fit: pw.BoxFit.contain,
                      width: 48,
                      height: 48,
                    ),
                  ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  line.name,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 13,
                    color: notePdfInk,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  line.quantityPriceLabel,
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 11,
                    color: notePdfMuted,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            formatBrl(line.totalCents),
            style: pw.TextStyle(
              font: bold,
              fontSize: 13,
              color: notePdfInk,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _totals(NotePdfSnapshot snapshot) {
    final open = snapshot.openBalanceCents;
    final showBoth =
        !snapshot.isDraft && open != null && open != snapshot.noteTotalCents;

    final rows = <({String label, int cents})>[];
    if (snapshot.isDraft) {
      rows.add((label: 'Total da nota', cents: snapshot.noteTotalCents));
    } else if (showBoth) {
      rows.add((label: 'Total da nota', cents: snapshot.noteTotalCents));
      rows.add((label: 'Saldo em aberto', cents: open));
    } else {
      rows.add((
        label: 'Total em aberto',
        cents: open ?? snapshot.noteTotalCents,
      ));
    }

    return pw.Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            decoration: pw.BoxDecoration(
              color: notePdfForest,
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    rows[i].label,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 13,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.Text(
                  formatBrl(rows[i].cents),
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 18,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          if (i < rows.length - 1) pw.SizedBox(height: 10),
        ],
      ],
    );
  }
}
