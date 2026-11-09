import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exceptions.dart';

const streetLedgerKey = 'street_ledger';

abstract class WorkspaceLocalDataSource {
  String? readStreetLedger();

  Future<void> saveStreetLedger(String json);
}

class WorkspaceLocalDataSourceImpl implements WorkspaceLocalDataSource {
  WorkspaceLocalDataSourceImpl({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  @override
  String? readStreetLedger() {
    try {
      return sharedPreferences.getString(streetLedgerKey);
    } catch (_) {
      throw CacheException();
    }
  }

  @override
  Future<void> saveStreetLedger(String json) async {
    try {
      final saved = await sharedPreferences.setString(streetLedgerKey, json);
      if (!saved) throw CacheException();
    } on CacheException {
      rethrow;
    } catch (_) {
      throw CacheException();
    }
  }
}
