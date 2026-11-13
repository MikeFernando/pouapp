import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/street_ledger.dart';

/// Persists home "Recebimentos do dia" checklist marks for the calendar day.
class DayChecklistStore {
  DayChecklistStore({required SharedPreferences sharedPreferences})
    : _prefs = sharedPreferences;

  final SharedPreferences _prefs;

  static String _key(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return 'day_checklist_served_${isoDate(start)}';
  }

  Set<String> loadServed(DateTime day) {
    final stored = _prefs.getStringList(_key(day));
    if (stored == null || stored.isEmpty) return {};
    return stored.toSet();
  }

  Future<void> saveServed(DateTime day, Set<String> ids) async {
    final key = _key(day);
    if (ids.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    final sorted = ids.toList()..sort();
    await _prefs.setStringList(key, sorted);
  }
}
