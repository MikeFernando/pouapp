import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/workspace_mode.dart';

const workspaceModeKey = 'workspace_mode';
const streetLedgerKey = 'street_ledger';

abstract class WorkspaceLocalDataSource {
  WorkspaceMode readMode();

  Future<void> saveMode(WorkspaceMode mode);

  String? readStreetLedger();

  Future<void> saveStreetLedger(String json);
}

class WorkspaceLocalDataSourceImpl implements WorkspaceLocalDataSource {
  WorkspaceLocalDataSourceImpl({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  @override
  WorkspaceMode readMode() {
    try {
      return workspaceModeFromStorage(
        sharedPreferences.getString(workspaceModeKey),
      );
    } catch (_) {
      throw CacheException();
    }
  }

  @override
  Future<void> saveMode(WorkspaceMode mode) async {
    try {
      final saved = await sharedPreferences.setString(
        workspaceModeKey,
        workspaceModeStorageValue(mode),
      );
      if (!saved) throw CacheException();
    } on CacheException {
      rethrow;
    } catch (_) {
      throw CacheException();
    }
  }

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
