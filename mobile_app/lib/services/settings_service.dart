import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'supabase_repository.dart';

// Current app version — keep in sync with pubspec.yaml
const kAppVersion = '1.0.0';
const kAppBuildNumber = 1;
const kAppPlatform = String.fromEnvironment('PLATFORM', defaultValue: 'ios');

class UpdateInfo {
  final String latestVersion;
  final int latestBuild;
  final String releaseNotes;
  final bool isForced; // min_supported_version > current

  const UpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.releaseNotes,
    required this.isForced,
  });
}

/// Compares two semver strings. Returns negative if a < b, 0 if equal, positive if a > b.
int _compareSemver(String a, String b) {
  final aParts = a.split('.').map(int.tryParse).toList();
  final bParts = b.split('.').map(int.tryParse).toList();
  for (int i = 0; i < 3; i++) {
    final av = i < aParts.length ? (aParts[i] ?? 0) : 0;
    final bv = i < bParts.length ? (bParts[i] ?? 0) : 0;
    if (av != bv) return av - bv;
  }
  return 0;
}

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._internal();

  Box<Map>? _box;

  SettingsService._internal();

  Future<void> init() async {
    _box = await Hive.openBox<Map>('app_settings');
    // Ensure keys exist
    if (!_box!.containsKey('categories')) {
      await _box!.put('categories', {'items': []});
    }
    if (!_box!.containsKey('groups')) {
      await _box!.put('groups', {'items': []});
    }
    if (!_box!.containsKey('organizations')) {
      await _box!.put('organizations', {'items': []});
    }
    if (!_box!.containsKey('users')) {
      await _box!.put('users', {'items': []});
    }
    if (!_box!.containsKey('app_info')) {
      await _box!.put('app_info', {'version': '1.0.0'});
    }
  }

  List<String> getCategories() {
    final data = _box!.get('categories')!['items'] as List;
    return List<String>.from(data);
  }

  Future<void> addCategory(String name) async {
    final list = getCategories();
    if (!list.contains(name)) {
      list.add(name);
      await _box!.put('categories', {'items': list});
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String name) async {
    final list = getCategories();
    list.remove(name);
    await _box!.put('categories', {'items': list});
    notifyListeners();
  }

  List<String> getGroups() {
    final data = _box!.get('groups')!['items'] as List;
    return List<String>.from(data);
  }

  Future<void> addGroup(String name) async {
    final list = getGroups();
    if (!list.contains(name)) {
      list.add(name);
      await _box!.put('groups', {'items': list});
      notifyListeners();
    }
  }

  Future<void> deleteGroup(String name) async {
    final list = getGroups();
    list.remove(name);
    await _box!.put('groups', {'items': list});
    notifyListeners();
  }

  Map getAppInfo() {
    return Map<String, dynamic>.from(_box!.get('app_info')!);
  }

  Future<void> setAppVersion(String version) async {
    await _box!.put('app_info', {'version': version});
    notifyListeners();
  }

  // ── Update checking ──────────────────────────────────────────────────────

  UpdateInfo? _pendingUpdate;
  UpdateInfo? get pendingUpdate => _pendingUpdate;

  /// Fetches the latest version from Supabase and compares with [kAppVersion].
  /// Returns an [UpdateInfo] if an update is available, null otherwise.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final repo = SupabaseRepository();
      final platform = _resolvePlatform();
      final data = await repo.fetchLatestVersion(platform);
      if (data == null) return null;

      final latest = data['version'] as String? ?? kAppVersion;
      final latestBuild = data['build_number'] as int? ?? kAppBuildNumber;
      final notes = data['release_notes'] as String? ?? '';
      final minSupported = data['min_supported_version'] as String? ?? '0.0.0';

      final hasUpdate = _compareSemver(latest, kAppVersion) > 0 ||
          (latest == kAppVersion && latestBuild > kAppBuildNumber);

      if (!hasUpdate) {
        _pendingUpdate = null;
        notifyListeners();
        return null;
      }

      final isForced = _compareSemver(minSupported, kAppVersion) > 0;
      _pendingUpdate = UpdateInfo(
        latestVersion: latest,
        latestBuild: latestBuild,
        releaseNotes: notes,
        isForced: isForced,
      );
      notifyListeners();
      return _pendingUpdate;
    } catch (e) {
      debugPrint('[UpdateCheck] error: $e');
      return null;
    }
  }

  String _resolvePlatform() {
    // Detect at runtime — kAppPlatform can be overridden via --dart-define
    if (kAppPlatform != 'ios') return kAppPlatform;
    // Default: check compile-time platform
    return 'ios'; // change to 'android' via --dart-define=PLATFORM=android
  }

  /// Pull categories and groups from Supabase, merge with local (union — no deletions).
  Future<void> syncDownFromCloud(SupabaseRepository repo) async {
    try {
      final remote = await repo.fetchUserSettings();
      if (remote == null) return;

      final remoteCategories = List<String>.from(remote['categories'] ?? []);
      final remoteGroups = List<String>.from(remote['groups'] ?? []);

      // Union: add remote items that don't exist locally
      for (final c in remoteCategories) {
        await addCategory(c);
      }
      for (final g in remoteGroups) {
        await addGroup(g);
      }
      debugPrint('[SettingsSync] Down: ${remoteCategories.length} categories, ${remoteGroups.length} groups');
    } catch (e) {
      debugPrint('[SettingsSync] syncDownFromCloud error: $e');
    }
  }

  /// Push local categories and groups up to Supabase.
  Future<void> syncUpToCloud(SupabaseRepository repo) async {
    try {
      await repo.upsertUserSettings(
        categories: getCategories(),
        groups: getGroups(),
      );
      debugPrint('[SettingsSync] Up: ${getCategories().length} categories, ${getGroups().length} groups');
    } catch (e) {
      debugPrint('[SettingsSync] syncUpToCloud error: $e');
    }
  }
}
