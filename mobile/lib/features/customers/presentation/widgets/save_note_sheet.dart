import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_note.dart';
import '../note_share.dart';

enum SaveNoteChoice { sendPdf, saveWithoutSending }

/// Bottom sheet after Salvar: send the note PDF or keep it without sending.
Future<SaveNoteChoice?> showSaveNoteSheet({
  required BuildContext context,
  required Customer customer,
  required CustomerNote note,
}) {
  return showModalBottomSheet<SaveNoteChoice>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _SaveNoteSheet(customer: customer, note: note),
  );
}

class _SaveNoteSheet extends StatefulWidget {
  const _SaveNoteSheet({required this.customer, required this.note});

  final Customer customer;
  final CustomerNote note;

  @override
  State<_SaveNoteSheet> createState() => _SaveNoteSheetState();
}

class _SaveNoteSheetState extends State<_SaveNoteSheet> {
  static const _ink = Color(0xFF121417);
  static const _muted = Color(0xFF6B7280);
  static const _green = Color(0xFF305536);

  var _busy = false;
  String? _error;

  Future<void> _sendPdf() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await shareCustomerNotePdf(
        customer: widget.customer,
        note: widget.note.copyWith(lines: List.of(widget.note.lines)),
        sharePositionOrigin: origin,
      );
      if (!mounted) return;
      Navigator.of(context).pop(SaveNoteChoice.sendPdf);
    } catch (error, stack) {
      debugPrint('save note send pdf failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Não foi possível gerar a nota. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasWhatsApp = customerWhatsAppDigits(widget.customer) != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Salvar nota',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('save_note_close'),
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F2F7),
                    foregroundColor: _ink,
                  ),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Escolha como concluir esta nota.',
              style: TextStyle(fontSize: 14, color: _muted, height: 1.35),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('save_note_error'),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFC62828),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: FilledButton(
                key: const Key('save_note_send_pdf'),
                onPressed: _busy ? null : _sendPdf,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFB7C4B9),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  _busy
                      ? 'Gerando PDF…'
                      : hasWhatsApp
                      ? 'Enviar PDF ao cliente'
                      : 'Compartilhar PDF da nota',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                key: const Key('save_note_without_sending'),
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(
                          SaveNoteChoice.saveWithoutSending,
                        ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: pouBrand,
                  side: const BorderSide(color: pouBrand, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Salvar sem enviar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
