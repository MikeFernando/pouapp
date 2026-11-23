import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/business_look.dart';

/// Visual theme chosen on the home header, stored per business.
///
/// Missing means the business still uses the type from the initial setup.
/// Saving here does not change that registered type.
class BusinessThemeStore {
  BusinessThemeStore({required SharedPreferences sharedPreferences})
    : _prefs = sharedPreferences;

  final SharedPreferences _prefs;

  static String keyFor(String userId) => 'business_theme.$userId';

  PouChrome? read(String userId) {
    return _parse(_prefs.getString(keyFor(userId)));
  }

  Future<void> save(String userId, PouChrome chrome) {
    return _prefs.setString(keyFor(userId), chrome.name);
  }

  PouChrome? _parse(String? raw) {
    return switch (raw) {
      'botanical' => PouChrome.botanical,
      'cleaning' => PouChrome.cleaning,
      'meals' => PouChrome.meals,
      'pizzas' => PouChrome.pizzas,
      'snacks' => PouChrome.snacks,
      'cakes' => PouChrome.cakes,
      _ => null,
    };
  }
}
