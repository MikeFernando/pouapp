import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/home_board.dart';
import '../domain/entities/street_ledger.dart';
import 'models/home_board_model.dart';

/// Last successful `/workspace/home` payload for offline cold starts.
class HomeBoardCache {
  HomeBoardCache({required SharedPreferences sharedPreferences})
    : _prefs = sharedPreferences;

  final SharedPreferences _prefs;

  static const _key = 'home_board_cache_v1';

  HomeBoard? read({String? date}) {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final board = HomeBoardModel.fromJson(Map<String, dynamic>.from(json));
      if (date != null && date.isNotEmpty && board.date != date) {
        // Stale calendar day — still useful for structure; caller may keep it.
      }
      return board;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(HomeBoard board) async {
    final payload = HomeBoardModel(
      date: board.date,
      receivedTodayCents: board.receivedTodayCents,
      receiptsDueToday: board.receiptsDueToday,
      duesTomorrow: board.duesTomorrow,
      upcomingDues: board.upcomingDues,
    ).toJson();
    await _prefs.setString(_key, jsonEncode(payload));
  }
}

HomeBoard emptyHomeBoard([DateTime? now]) {
  return HomeBoard(
    date: isoDate(now ?? DateTime.now()),
    receivedTodayCents: 0,
    receiptsDueToday: const [],
    duesTomorrow: const [],
    upcomingDues: const [],
  );
}
