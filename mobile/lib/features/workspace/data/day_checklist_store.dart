import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/street_ledger.dart';
import '../domain/rules/month_board.dart';

/// Persists home "Recebimentos do dia" checklist marks for the calendar day.
///
/// Served ids alone are not enough: after the note is deleted the customer
/// leaves today's list, but Financeiro / Recebido hoje must keep the value.
class DayChecklistStore {
  DayChecklistStore({required SharedPreferences sharedPreferences})
    : _prefs = sharedPreferences;

  final SharedPreferences _prefs;

  static String _servedKey(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return 'day_checklist_served_${isoDate(start)}';
  }

  static String _frozenKey(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return 'day_checklist_frozen_${isoDate(start)}';
  }

  static const _committedKey = 'finance_committed_receipts_v1';

  Set<String> loadServed(DateTime day) {
    final stored = _prefs.getStringList(_servedKey(day));
    if (stored == null || stored.isEmpty) return {};
    return stored.toSet();
  }

  Future<void> saveServed(DateTime day, Set<String> ids) async {
    final key = _servedKey(day);
    if (ids.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    final sorted = ids.toList()..sort();
    await _prefs.setStringList(key, sorted);
  }

  Map<String, DayChecklistFrozen> loadFrozen(DateTime day) {
    final raw = _prefs.getString(_frozenKey(day));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, DayChecklistFrozen>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        out[entry.key.toString()] = DayChecklistFrozen.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveFrozen(
    DateTime day,
    Map<String, DayChecklistFrozen> frozen,
  ) async {
    final key = _frozenKey(day);
    if (frozen.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    final payload = <String, Object?>{
      for (final entry in frozen.entries) entry.key: entry.value.toJson(),
    };
    await _prefs.setString(key, jsonEncode(payload));
  }

  /// Notes deleted after they were marked received. These stay in Financeiro
  /// even though the open note is gone. Unmarking never writes here.
  Map<String, DayChecklistFrozen> loadCommitted() => _readMap(_committedKey);

  DayChecklistFrozen committedTotal() {
    var cents = 0;
    final products = <String, int>{};
    for (final entry in loadCommitted().values) {
      cents += entry.receivedCents;
      for (final item in entry.productCents.entries) {
        products[item.key] = (products[item.key] ?? 0) + item.value;
      }
    }
    return DayChecklistFrozen(receivedCents: cents, productCents: products);
  }

  Future<void> commitReceipt({
    required String noteId,
    required DayChecklistFrozen entry,
  }) async {
    if (noteId.isEmpty || entry.receivedCents <= 0) return;
    final current = loadCommitted();
    current[noteId] = entry;
    await _writeMap(_committedKey, current);
  }

  Map<String, DayChecklistFrozen> _readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, DayChecklistFrozen>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        out[entry.key.toString()] = DayChecklistFrozen.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMap(
    String key,
    Map<String, DayChecklistFrozen> entries,
  ) async {
    if (entries.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(key, jsonEncode({
      for (final entry in entries.entries) entry.key: entry.value.toJson(),
    }));
  }
}
