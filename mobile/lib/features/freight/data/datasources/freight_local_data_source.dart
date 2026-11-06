import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exceptions.dart';

const freightLedgerKey = 'freight_ledger';

abstract class FreightLocalDataSource {
  String? readLedger();

  Future<void> saveLedger(String json);
}

class FreightLocalDataSourceImpl implements FreightLocalDataSource {
  FreightLocalDataSourceImpl({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  @override
  String? readLedger() {
    try {
      return sharedPreferences.getString(freightLedgerKey);
    } catch (_) {
      throw CacheException();
    }
  }

  @override
  Future<void> saveLedger(String json) async {
    try {
      final saved = await sharedPreferences.setString(freightLedgerKey, json);
      if (!saved) throw CacheException();
    } on CacheException {
      rethrow;
    } catch (_) {
      throw CacheException();
    }
  }
}
