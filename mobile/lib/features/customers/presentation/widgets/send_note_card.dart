import 'package:flutter/material.dart';

import '../../../../app/pou_app_colors.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_note.dart';
import '../note_share.dart';
import 'customer_action_card.dart';

String _sendNoteSubtitle({
  required bool hasItems,
  required bool busy,
  required bool hasWhatsApp,
  String? error,
}) {
  if (!hasItems) return 'Adicione um item para enviar';
  if (busy) return 'Gerando PDF…';
  if (error != null) return error;
  if (hasWhatsApp) return 'Enviar PDF pelo WhatsApp';
  return 'Compartilhar PDF com itens e valores';
}

/// Compact card under the due date that shares the current note as a PDF.
class SendNoteCard extends StatefulWidget {
  const SendNoteCard({
    super.key,
    required this.customer,
    required this.note,
  });

  final Customer customer;
  final CustomerNote? note;

  @override
  State<SendNoteCard> createState() => _SendNoteCardState();
}

class _SendNoteCardState extends State<SendNoteCard> {
  var _busy = false;
  String? _error;

  bool get _hasItems => (widget.note?.lines.isNotEmpty ?? false);

  Future<void> _share() async {
    final note = widget.note;
    if (note == null || !_hasItems || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Capture a consistent snapshot of what the user sees right now.
      final snapshot = note.copyWith(lines: List.of(note.lines));
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await shareCustomerNotePdf(
        customer: widget.customer,
        note: snapshot,
        sharePositionOrigin: origin,
      );
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (error, stack) {
      debugPrint('send note failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Não foi possível gerar a nota. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _hasItems;
    final hasWhatsApp = customerWhatsAppDigits(widget.customer) != null;
    final subtitle = _sendNoteSubtitle(
      hasItems: _hasItems,
      busy: _busy,
      hasWhatsApp: hasWhatsApp,
      error: _error,
    );

    return CustomerActionCard(
      inkWellKey: const Key('send_note_card'),
      labelFirst: false,
      title: 'Enviar nota ao cliente',
      label: subtitle,
      labelKey: Key(
        _error != null
            ? 'send_note_error'
            : !_hasItems
            ? 'send_note_empty'
            : 'send_note_subtitle',
      ),
      labelColor: _error != null ? const Color(0xFFC62828) : null,
      enabled: enabled,
      busy: _busy,
      onTap: _share,
      icon: SendNoteFileIcon(
        color: enabled ? pouBrand : const Color(0xFFD1D5DB),
      ),
    );
  }
}
