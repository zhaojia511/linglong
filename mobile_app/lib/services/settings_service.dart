import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

  Future<bool> checkForUpdate() async {
    // Placeholder: real implementation should call server or update-service
    await Future.delayed(const Duration(seconds: 1));
    return false;
  }
}
