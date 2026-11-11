import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';
import '../../../catalog/presentation/produce_assets.dart';
import '../../../workspace/presentation/operation_labels.dart';
import '../../domain/entities/customer_note.dart';
import '../../domain/rules/note_rules.dart';

const _sheetBg = Color(0xFFF5F6F5);
const _titleColor = Color(0xFF141615);
const _muted = Color(0xFF737874);
const _handle = Color(0xFFBFC3C4);
const _closeBg = Color(0xFFE6E8E7);
const _cardBorder = Color(0xFFE1E8E3);
const _divider = Color(0xFFE6EBE7);
const _iconTileBg = Color(0xFFE2F1E8);
const _iconStroke = Color(0xFF17613D);

Future<void> showDeletedNotesSheet(
  BuildContext context, {
  required String customerName,
  required List<CustomerNote> notes,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DeletedNotesSheet(
      customerName: customerName,
      notes: notes,
    ),
  );
}

class DeletedNotesSheet extends StatelessWidget {
  const DeletedNotesSheet({
    super.key,
    required this.customerName,
    required this.notes,
  });

  final String customerName;
  final List<CustomerNote> notes;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.top - 24;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          minWidth: double.infinity,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 11),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: _handle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text(
                          'Notas excluídas',
                          key: Key('deleted_notes_title'),
                          style: TextStyle(
                            fontSize: 20,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: _titleColor,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Material(
                            color: _closeBg,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => Navigator.of(context).maybePop(),
                              child: const SizedBox(
                                width: 32,
                                height: 32,
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Color(0xFF3F4541),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 48),
                      child: Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (notes.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 8, 18, 28),
                child: Text(
                  'Nenhuma nota excluída.',
                  key: Key('deleted_notes_empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(13, 0, 13, 16),
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _DeletedNoteCard(
                      key: Key('deleted_note_${notes[index].id}'),
                      note: notes[index],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeletedNoteCard extends StatefulWidget {
  const _DeletedNoteCard({super.key, required this.note});

  final CustomerNote note;

  @override
  State<_DeletedNoteCard> createState() => _DeletedNoteCardState();
}

class _DeletedNoteCardState extends State<_DeletedNoteCard> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final count = note.lines.length;
    final itemsLabel = count == 1 ? '1 item' : '$count itens';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const _DocumentIconTile(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatDeletedNoteDay(note.updatedAt.toLocal()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: _titleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              itemsLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatBrl(note.totalCents),
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: _titleColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _open ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: pouBrand,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_open) ...[
              if (note.lines.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nenhum item nesta nota.',
                      style: TextStyle(fontSize: 14, color: _muted),
                    ),
                  ),
                )
              else
                for (final line in note.lines) ...[
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 14,
                    endIndent: 14,
                    color: _divider,
                  ),
                  _DeletedNoteLineRow(line: line),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentIconTile extends StatelessWidget {
  const _DocumentIconTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _iconTileBg,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: const CustomPaint(
        size: Size(22, 22),
        painter: _DocumentOutlinePainter(_iconStroke),
      ),
    );
  }
}

class _DocumentOutlinePainter extends CustomPainter {
  const _DocumentOutlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final page = Path()
      ..moveTo(size.width * 0.22, size.height * 0.10)
      ..lineTo(size.width * 0.58, size.height * 0.10)
      ..lineTo(size.width * 0.78, size.height * 0.30)
      ..lineTo(size.width * 0.78, size.height * 0.90)
      ..lineTo(size.width * 0.22, size.height * 0.90)
      ..close();
    canvas.drawPath(page, stroke);

    canvas.drawLine(
      Offset(size.width * 0.58, size.height * 0.10),
      Offset(size.width * 0.58, size.height * 0.30),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.58, size.height * 0.30),
      Offset(size.width * 0.78, size.height * 0.30),
      stroke,
    );

    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.48),
      Offset(size.width * 0.66, size.height * 0.48),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.64),
      Offset(size.width * 0.60, size.height * 0.64),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _DocumentOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DeletedNoteLineRow extends StatelessWidget {
  const _DeletedNoteLineRow({required this.line});

  final NoteLine line;

  @override
  Widget build(BuildContext context) {
    final photo = produceAsset(line.name);
    final qtyLabel = formatDeletedNoteQuantity(line);
    final unitPrice = formatBrl(line.unitPriceCents);
    final subtotal = formatBrl(line.totalCents);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 66),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 52,
              height: 44,
              child: photo == null
                  ? const ColoredBox(
                      color: Color(0xFFE9E8EB),
                      child: Icon(
                        Icons.eco_outlined,
                        color: Color(0xFF9CA3AF),
                        size: 22,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.contain,
                      child: Image.asset(photo, fit: BoxFit.contain),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    line.name,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: _titleColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$qtyLabel × $unitPrice',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              subtotal,
              style: const TextStyle(
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: _titleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date like `11 nov. 2026` for deleted-note headers.
String formatDeletedNoteDay(DateTime date) {
  const months = <String>[
    'jan.',
    'fev.',
    'mar.',
    'abr.',
    'mai.',
    'jun.',
    'jul.',
    'ago.',
    'set.',
    'out.',
    'nov.',
    'dez.',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Quantity label without trailing `.0` when whole (matches reference `1 ×`).
String formatDeletedNoteQuantity(NoteLine line) {
  final display = displayQuantity(line.unit, line.quantity);
  if (display == display.roundToDouble()) {
    return display.round().toString();
  }
  return display
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '')
      .replaceAll('.', ',');
}
