import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local profile photo per account (gallery pick — not synced to the API yet).
class ProfileAvatarStore {
  ProfileAvatarStore({required SharedPreferences sharedPreferences})
    : _prefs = sharedPreferences;

  final SharedPreferences _prefs;

  static String _key(String userId) => 'profile_avatar_path_$userId';

  Future<String?> pathForUser(String userId) async {
    final stored = _prefs.getString(_key(userId));
    if (stored == null || stored.isEmpty) return null;
    if (!File(stored).existsSync()) {
      await _prefs.remove(_key(userId));
      return null;
    }
    return stored;
  }

  Future<String> saveFromGallery({
    required String userId,
    required String sourcePath,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'profile_avatars'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final ext = p.extension(sourcePath).toLowerCase();
    final safeExt = (ext == '.png' || ext == '.webp' || ext == '.jpeg')
        ? ext
        : '.jpg';
    final target = File(p.join(dir.path, '$userId$safeExt'));
    if (target.existsSync()) {
      await target.delete();
    }
    await File(sourcePath).copy(target.path);

    final previous = _prefs.getString(_key(userId));
    await _prefs.setString(_key(userId), target.path);
    if (previous != null &&
        previous.isNotEmpty &&
        previous != target.path &&
        File(previous).existsSync()) {
      await File(previous).delete();
    }
    return target.path;
  }
}
