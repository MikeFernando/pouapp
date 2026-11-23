import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/business_setup.dart';
import '../models/business_setup_model.dart';

/// Per-account cache. The key includes the user id, so it is not an
/// install-wide flag.
class BusinessSetupLocalDataSource {
  BusinessSetupLocalDataSource({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  static String keyFor(String userId) => 'business_setup.$userId';

  Future<BusinessSetup?> read(String userId) async {
    final raw = sharedPreferences.getString(keyFor(userId));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return BusinessSetupModel.fromJson(
      userId,
      Map<String, dynamic>.from(decoded),
    );
  }

  Future<void> save(BusinessSetup setup) async {
    final model = setup is BusinessSetupModel
        ? setup
        : BusinessSetupModel(
            userId: setup.userId,
            status: setup.status,
            kind: setup.kind,
            categories: setup.categories,
          );
    final saved = await sharedPreferences.setString(
      keyFor(setup.userId),
      jsonEncode(model.toJson()),
    );
    if (!saved) {
      throw StateError('Não foi possível guardar o tipo do negócio.');
    }
  }

  /// Writes `pending` only when this account has no setup record yet.
  Future<void> markPending(String userId) async {
    final existing = await read(userId);
    if (existing != null) return;
    await save(BusinessSetup.pending(userId));
  }
}
