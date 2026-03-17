import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../supabase/supabase_client.dart';
import 'database_service.dart';
import 'settings_service.dart';

class AppInitializer {
  AppInitializer._internal();
  static final AppInitializer instance = AppInitializer._internal();

  final Completer<void> _completer = Completer<void>();
  bool _started = false;
  Object? error;

  Future<void> get initFuture => _completer.future;

  /// Start initialization asynchronously. Safe to call multiple times.
  void start() {
    if (_started) return;
    _started = true;
    _run();
  }

  Future<void> _run() async {
    try {
      // Initialize Hive and other platform-level things
      WidgetsFlutterBinding.ensureInitialized();
      await Hive.initFlutter();

      // Initialize Supabase (if used)
      await SupabaseClientProvider.init();

      // Initialize application services (DB, settings)
      await DatabaseService.instance.init();
      await SettingsService.instance.init();

      _completer.complete();

      // Non-blocking version check after init
      SettingsService.instance.checkForUpdate().ignore();
    } catch (e, st) {
      error = e;
      if (!_completer.isCompleted) _completer.completeError(e, st);
    }
  }
}
