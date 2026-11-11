/// Runtime API wiring for the PouApp backend.
///
/// Defaults to the Railway production host. Override locally with
/// `--dart-define=API_BASE_URL=http://127.0.0.1:3333` (iOS) or
/// `--dart-define=API_BASE_URL=http://10.0.2.2:3333` (Android emulator).
/// Force the old simulated auth with `--dart-define=USE_SIMULATED_AUTH=true`.
class ApiConfig {
  const ApiConfig._();

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Public Railway URL (no custom domain required).
  static const String productionBaseUrl =
      'https://pouapp-api-production.up.railway.app';

  static const bool useSimulatedAuth = bool.fromEnvironment(
    'USE_SIMULATED_AUTH',
    defaultValue: false,
  );

  static bool get useRemoteApi => !useSimulatedAuth;

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    return productionBaseUrl;
  }

  /// Stripe Payment Link (admin / tooling). Override with dart-define.
  static const String stripePaymentLinkUrl = String.fromEnvironment(
    'STRIPE_PAYMENT_LINK_URL',
    defaultValue: 'https://buy.stripe.com/test_fZu9ATglqdAY6PI2FPfIs00',
  );

  /// Your WhatsApp in international digits (country + DDD + number).
  /// Example BR: `5511999998888`. Override with
  /// `--dart-define=SUPPORT_WHATSAPP_DIGITS=...`.
  static const String supportWhatsAppDigits = String.fromEnvironment(
    'SUPPORT_WHATSAPP_DIGITS',
    defaultValue: '5515992639023',
  );
}
