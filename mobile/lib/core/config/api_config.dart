import 'dart:io';

/// Runtime API wiring for the PouApp backend.
///
/// Override with `--dart-define=API_BASE_URL=...`.
/// Android emulator defaults to `http://10.0.2.2:3333`.
/// iOS simulator / desktop default to `http://127.0.0.1:3333`.
/// Physical devices need the host LAN IP via dart-define.
/// Force the old simulated auth with `--dart-define=USE_SIMULATED_AUTH=true`.
class ApiConfig {
  const ApiConfig._();

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const bool useSimulatedAuth = bool.fromEnvironment(
    'USE_SIMULATED_AUTH',
    defaultValue: false,
  );

  static bool get useRemoteApi => !useSimulatedAuth;

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    if (Platform.isAndroid) return 'http://10.0.2.2:3333';
    return 'http://127.0.0.1:3333';
  }
}
