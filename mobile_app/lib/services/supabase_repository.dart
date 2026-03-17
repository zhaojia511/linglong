import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_client.dart';

class SupabaseRepository {
  SupabaseRepository() : _client = SupabaseClientProvider.client;

  final SupabaseClient _client;

  // Auth
  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String email, String password) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  // Persons
  Future<List<Map<String, dynamic>>> fetchPersons() async {
    final res = await _client.from('persons').select().order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> upsertPerson({
    required String name,
    required int age,
    required String gender,
    required double weight,
    required double height,
    int? maxHeartRate,
    int? restingHeartRate,
    String? id,
    String? role,
    String? category,
    String? group,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final payload = {
      'id': id,
      'user_id': userId,
      'name': name,
      'age': age,
      'gender': gender,
      'weight': weight,
      'height': height,
      'max_heart_rate': maxHeartRate,
      'resting_heart_rate': restingHeartRate,
      'role': role,
      'category': category,
      'group': group,
    }..removeWhere((_, v) => v == null);
    await _client.from('persons').upsert(payload);
  }

  // Sessions
  Future<List<Map<String, dynamic>>> fetchSessions() async {
    final res = await _client.from('training_sessions').select().order('start_time', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> createSession({
    required String personId,
    required String title,
    required String trainingType,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    await _client.from('training_sessions').insert({
      'user_id': userId,
      'person_id': personId,
      'title': title,
      'training_type': trainingType,
      'notes': notes,
      'start_time': DateTime.now().toIso8601String(),
      'heart_rate_data': jsonEncode([]),
    });
  }

  Future<void> appendHeartRate(String sessionId, List<Map<String, dynamic>> data) async {
    await _client.from('training_sessions').update({
      'heart_rate_data': jsonEncode(data),
    }).eq('id', sessionId);
  }

  Future<void> endSession(String sessionId, {
    required DateTime startTime,
    required List<int> heartRates,
    required double weight,
    required int age,
    required String gender,
    String? notes,
  }) async {
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inSeconds;
    int? avg, max, min;
    double? calories;
    if (heartRates.isNotEmpty) {
      avg = heartRates.reduce((a, b) => a + b) ~/ heartRates.length;
      max = heartRates.reduce((a, b) => a > b ? a : b);
      min = heartRates.reduce((a, b) => a < b ? a : b);
      calories = _estimateCalories(avg, duration, weight, age, gender);
    }
    await _client.from('training_sessions').update({
      'end_time': endTime.toIso8601String(),
      'duration': duration,
      'avg_heart_rate': avg,
      'max_heart_rate': max,
      'min_heart_rate': min,
      'calories': calories,
      'notes': notes,
      'synced': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  /// Upsert a complete training session to Supabase
  Future<void> upsertTrainingSession({
    required String id,
    required String personId,
    required String title,
    required String trainingType,
    required DateTime startTime,
    required DateTime endTime,
    required int duration,
    required int avgHeartRate,
    required int maxHeartRate,
    required int minHeartRate,
    required double calories,
    required List<Map<String, dynamic>> heartRateData,
    String? notes,
    List<int>? rrIntervals,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    
    try {
      debugPrint('Upserting session $id to Supabase');
      debugPrint('  person_id: $personId');
      debugPrint('  user_id: $userId');
      debugPrint('  title: $title');
      debugPrint('  heart_rate_data points: ${heartRateData.length}');
      
      final payload = {
        'id': id,
        'user_id': userId,
        'person_id': personId,
        'title': title,
        'training_type': trainingType,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'duration': duration,
        'avg_heart_rate': avgHeartRate,
        'max_heart_rate': maxHeartRate,
        'min_heart_rate': minHeartRate,
        'calories': calories,
        'heart_rate_data': jsonEncode(heartRateData),
        'notes': notes,
        'synced': true,
        'created_at': startTime.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      final result = await _client.from('training_sessions').upsert(payload).select();
      debugPrint('Supabase upsert result: $result');
    } catch (e) {
      debugPrint('Error upserting training session: $e');
      debugPrint('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  // User Settings (categories + groups)

  /// Fetch user settings (categories, groups) from Supabase.
  /// Table: user_settings (user_id text PK, categories jsonb, groups jsonb, updated_at timestamptz)
  Future<Map<String, dynamic>?> fetchUserSettings() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final res = await _client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return res;
  }

  Future<void> upsertUserSettings({
    required List<String> categories,
    required List<String> groups,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    await _client.from('user_settings').upsert({
      'user_id': userId,
      'categories': categories,
      'groups': groups,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// Fetch unsynced sessions from local database
  Future<List<Map<String, dynamic>>> getUnsyncedSessions() async {
    try {
      final res = await _client
          .from('training_sessions')
          .select()
          .eq('synced', false)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching unsynced sessions: $e');
      return [];
    }
  }

  // App version
  // Table: app_versions (platform text PK, version text, build_number int,
  //   release_notes text, min_supported_version text, updated_at timestamptz)
  // RLS: public SELECT allowed (no auth required)
  Future<Map<String, dynamic>?> fetchLatestVersion(String platform) async {
    try {
      final res = await _client
          .from('app_versions')
          .select()
          .eq('platform', platform)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('[UpdateCheck] fetchLatestVersion error: $e');
      return null;
    }
  }

  Future<void> upsertAppVersion({
    required String platform,
    required String version,
    required int buildNumber,
    required String releaseNotes,
    required String minSupportedVersion,
  }) async {
    await _client.from('app_versions').upsert({
      'platform': platform,
      'version': version,
      'build_number': buildNumber,
      'release_notes': releaseNotes,
      'min_supported_version': minSupportedVersion,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'platform');
  }

  double _estimateCalories(int avgHr, int durationSec, double weightKg, int age, String gender) {
    final durationMin = durationSec / 60.0;
    if (gender == 'male') {
      return ((age * 0.2017) - (weightKg * 0.09036) + (avgHr * 0.6309) - 55.0969) * durationMin / 4.184;
    } else {
      return ((age * 0.074) - (weightKg * 0.05741) + (avgHr * 0.4472) - 20.4022) * durationMin / 4.184;
    }
  }
}
