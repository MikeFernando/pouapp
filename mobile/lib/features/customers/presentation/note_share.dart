import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../injection_container.dart';
import '../../workspace/data/receivable_store.dart';
import '../../workspace/domain/rules/receivable_rules.dart';
import '../../workspace/presentation/operation_labels.dart';
import '../data/note_pdf_document.dart';
import '../domain/entities/customer.dart';
import '../domain/entities/customer_note.dart';

const _whatsAppShareChannel = MethodChannel('com.pouapp.app/whatsapp_share');

/// Builds and shares the customer note PDF.
///
/// On Android, opens the customer's WhatsApp chat with the PDF attached when a
/// phone number is known. On iOS, WhatsApp URL schemes cannot attach files, so
/// the system share sheet is presented with the PDF (never an empty chat).
Future<void> shareCustomerNotePdf({
  required Customer customer,
  required CustomerNote note,
  Rect? sharePositionOrigin,
}) async {
  if (note.lines.isEmpty) {
    throw StateError('empty_note');
  }

  final images = await loadProduceImagesForLines(note.lines);
  int? openBalance;
  try {
    if (sl.isRegistered<ReceivableStore>()) {
      final account = await sl<ReceivableStore>().account(customer.id);
      if (account.receivables.isNotEmpty) {
        openBalance = account.openCents;
      }
    }
  } catch (error, stack) {
    debugPrint('note share: open balance skipped: $error\n$stack');
  }

  final snapshot = NotePdfSnapshot.fromNote(
    customerName: customer.name,
    note: note,
    imagesByProductName: images,
    openBalanceCents: openBalance,
  );

  final builder = await NotePdfDocument.loadAssets();
  final bytes = await builder.build(snapshot);
  final digits = customerWhatsAppDigits(customer);
  await sharePdfBytes(
    bytes: bytes,
    fileName: _pdfFileName(customer.name),
    subject: 'Nota PouApp - ${customer.name}',
    text: 'Segue a nota em PDF.',
    sharePositionOrigin: sharePositionOrigin,
    whatsAppDigits: digits,
  );
}

/// Digits for WhatsApp from mobile first, then landline.
String? customerWhatsAppDigits(Customer customer) {
  return whatsAppDigits(
    (customer.mobilePhone ?? '').trim().isNotEmpty
        ? customer.mobilePhone
        : customer.phone,
  );
}

Future<void> sharePdfBytes({
  required Uint8List bytes,
  required String fileName,
  String? subject,
  String? text,
  Rect? sharePositionOrigin,
  String? whatsAppDigits,
}) async {
  final dir = await getTemporaryDirectory();
  // share_plus / FileProvider serve from cache; keep the PDF there.
  final shareDir = Directory(p.join(dir.path, 'note_share'));
  if (!shareDir.existsSync()) {
    shareDir.createSync(recursive: true);
  }
  final file = File(p.join(shareDir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);

  final digits = whatsAppDigits?.trim();
  if (digits != null && digits.isNotEmpty) {
    // Android: open that chat with the PDF ready to send.
    final sentToChat = await _sharePdfToWhatsAppChat(
      filePath: file.path,
      digits: digits,
    );
    if (sentToChat) return;
  }

  // iOS (and Android fallback): share the PDF file. Do not open WhatsApp via
  // URL first — that only prefills text and hides the share sheet behind chat.
  final xFile = XFile(
    file.path,
    mimeType: 'application/pdf',
    name: fileName,
  );

  Future<ShareResult> present(Rect? origin) {
    return SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        subject: subject,
        text: text,
        sharePositionOrigin: origin,
        // Keep the sheet focused on sending the PDF (WhatsApp / WA Business).
        excludedCupertinoActivities: const [
          CupertinoActivityType.airDrop,
          CupertinoActivityType.mail,
          CupertinoActivityType.message,
          CupertinoActivityType.print,
          CupertinoActivityType.copyToPasteboard,
          CupertinoActivityType.assignToContact,
          CupertinoActivityType.addToReadingList,
          CupertinoActivityType.openInIBooks,
          CupertinoActivityType.markupAsPDF,
          CupertinoActivityType.postToFacebook,
          CupertinoActivityType.postToTwitter,
          CupertinoActivityType.postToWeibo,
          CupertinoActivityType.postToFlickr,
          CupertinoActivityType.postToVimeo,
          CupertinoActivityType.postToTencentWeibo,
        ],
      ),
    );
  }

  try {
    await present(sharePositionOrigin);
  } catch (error, stack) {
    debugPrint('note share: first attempt failed: $error\n$stack');
    final fallbackOrigin =
        sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 1, 1);
    await present(fallbackOrigin);
  }
}

/// Android: opens the customer's WhatsApp chat with the PDF ready to send.
Future<bool> _sharePdfToWhatsAppChat({
  required String filePath,
  required String digits,
}) async {
  if (kIsWeb || !Platform.isAndroid) return false;
  try {
    final ok = await _whatsAppShareChannel.invokeMethod<bool>(
      'sharePdf',
      <String, String>{'path': filePath, 'digits': digits},
    );
    return ok == true;
  } catch (error, stack) {
    debugPrint('note share: WhatsApp chat share failed: $error\n$stack');
    return false;
  }
}

String _pdfFileName(String customerName) {
  final slug = customerName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final stamp = formatDay(DateTime.now()).replaceAll('/', '-');
  final base = slug.isEmpty ? 'cliente' : slug;
  return 'nota_${base}_$stamp.pdf';
}
