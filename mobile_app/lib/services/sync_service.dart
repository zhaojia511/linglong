import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/person.dart';
import '../models/training_session.dart';
import '../supabase/supabase_client.dart';
import 'app_initializer.dart';
import 'database_service.dart';
import 'hrv_service.dart';
import 'settings_service.dart';
import 'supabase_repository.dart';

class SyncService extends ChangeNotifier {
  bool _isSyncing = false;
  final SupabaseRepository _repo = SupabaseRepository();

  SyncService() {
    _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        debugPrint('[SyncService] Signed in — triggering bidirectional sync');
        _syncOnLogin();
      }
    });
  }

  bool get isSyncing => _isSyncing;
  bool get isAuthenticated => SupabaseClientProvider.client.auth.currentSession != null;

  SupabaseClient get _client => SupabaseClientProvider.client;

  Future<void> _syncOnLogin() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();
    try {
      // Wait for DB/settings to finish initializing (important for session-restore on startup)
      await AppInitializer.instance.initFuture;
      final db = DatabaseService.instance;
      final settings = SettingsService.instance;
      final hrv = HrvService.instance;
      // Pull cloud data down first
      await settings.syncDownFromCloud(_repo);
      await db.syncDownFromCloud(_repo);
      await hrv.syncDownReadinessFromCloud(_repo);
      // Push local data up
      await settings.syncUpToCloud(_repo);
      await db.syncAllUnsyncedSessions(_repo);
      await hrv.syncAllUnsyncedReadiness(_repo);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
    notifyListeners();
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    notifyListeners();
  }

  Future<void> syncPerson(Person person) async {
    if (!isAuthenticated) return;
    final user = _client.auth.currentUser!;
    await _client.from('persons').upsert({
      'id': person.id,
      'user_id': user.id,
      'name': person.name,
      'age': person.age,
      'gender': person.gender,
      'weight': person.weight,
      'height': person.height,
      'max_heart_rate': person.maxHeartRate,
      'resting_heart_rate': person.restingHeartRate,
      'role': person.role,
      'category': person.category,
      'group': person.group,
    }, onConflict: 'id');
  }

  Future<void> syncSession(TrainingSession session) async {
    if (!isAuthenticated) return;
    final user = _client.auth.currentUser!;
    await _client.from('training_sessions').upsert({
      'id': session.id,
      'user_id': user.id,
      'person_id': session.personId,
      'title': session.title,
      'start_time': session.startTime.toIso8601String(),
      'end_time': session.endTime?.toIso8601String(),
      'duration': session.duration,
      'avg_heart_rate': session.avgHeartRate,
      'max_heart_rate': session.maxHeartRate,
      'min_heart_rate': session.minHeartRate,
      'calories': session.calories,
      'training_type': session.trainingType,
      'heart_rate_data': session.heartRateData.map((e) => e.toJson()).toList(),
      'notes': session.notes,
    }, onConflict: 'id');
  }

  Future<void> syncAll() async {
    if (!isAuthenticated || _isSyncing) return;
    await _syncOnLogin();
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
