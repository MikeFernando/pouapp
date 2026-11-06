import 'package:url_launcher/url_launcher.dart';

import '../../workspace/domain/rules/receivable_rules.dart';

const whatsAppLaunchTimeout = Duration(seconds: 3);

/// Opens the installed WhatsApp first. The web link is only a fallback, and
/// a slow network cannot hold the delivery screen.
Future<bool> launchCustomerWhatsApp(String digits, {String? message}) async {
  final opened = await launchExternalUri(
    whatsAppAppUri(digits: digits, message: message),
  );
  if (opened) return true;
  final web = message == null || message.trim().isEmpty
      ? Uri.parse('https://wa.me/$digits')
      : whatsAppChatUri(digits: digits, message: message);
  return launchExternalUri(web);
}

Future<bool> launchCustomerWhatsAppUri(Uri uri) async {
  final digits = whatsAppPhoneFromUri(uri);
  if (digits != null) {
    final opened = await launchExternalUri(
      whatsAppAppUri(digits: digits, message: uri.queryParameters['text']),
    );
    if (opened) return true;
  }
  return launchExternalUri(uri);
}

String? whatsAppPhoneFromUri(Uri uri) {
  if (uri.scheme == 'whatsapp') {
    final phone = uri.queryParameters['phone'];
    if (phone != null && phone.isNotEmpty) return phone;
  }
  if (uri.host == 'wa.me') {
    final path = uri.path.replaceAll('/', '');
    if (path.isNotEmpty) return path;
  }
  return null;
}

Future<bool> launchExternalUri(Uri uri) {
  try {
    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).timeout(whatsAppLaunchTimeout, onTimeout: () => false);
  } catch (_) {
    return Future<bool>.value(false);
  }
}
