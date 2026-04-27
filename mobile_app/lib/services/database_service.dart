import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/person.dart';
import '../models/training_session.dart';
import 'supabase_repository.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService instance = DatabaseService._internal();
  
  Box<Person>? _personBox;
  Box<TrainingSession>? _sessionBox;
  
  Person? _currentPerson;
  
  DatabaseService._internal();

  Future<void> init() async {
    try {
      // Register adapters before opening boxes
      if (!Hive.isAdapterRegistered(PersonAdapter().typeId)) {
        Hive.registerAdapter(PersonAdapter());
      }
      if (!Hive.isAdapterRegistered(TrainingSessionAdapter().typeId)) {
        Hive.registerAdapter(TrainingSessionAdapter());
      }
      if (!Hive.isAdapterRegistered(HeartRateDataAdapter().typeId)) {
        Hive.registerAdapter(HeartRateDataAdapter());
      }
      
      // Open boxes
      _personBox = await Hive.openBox<Person>('persons');
      _sessionBox = await Hive.openBox<TrainingSession>('training_sessions');
      
      // Load current person if exists
      if (_personBox!.isNotEmpty) {
        _currentPerson = _personBox!.values.first;
      }
    } catch (e) {
      debugPrint('Error initializing DatabaseService: $e');
      rethrow;
    }
  }

  Person? get currentPerson => _currentPerson;

  // Person Management
  Future<Person> createPerson({
    required String name,
    required int age,
    required String gender,
    required double weight,
    required double height,
    int? maxHeartRate,
    int? restingHeartRate,
    String? category,
    String? group,
  }) async {
    final person = Person(
      id: const Uuid().v4(),
      name: name,
      age: age,
      gender: gender,
      weight: weight,
      height: height,
      maxHeartRate: maxHeartRate,
      restingHeartRate: restingHeartRate,
      category: category,
      group: group,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await _personBox!.put(person.id, person);
    // Do not auto-select newly created person to avoid unexpected "selected" state
    notifyListeners();
    return person;
  }

  Future<void> updatePerson(Person person) async {
    person.updatedAt = DateTime.now();
    await _personBox!.put(person.id, person);
    if (_currentPerson?.id == person.id) {
      _currentPerson = person;
    }
    notifyListeners();
  }

  List<Person> getAllPersons() {
    return _personBox!.values.toList();
  }

  Future<void> deletePerson(String personId) async {
    await _personBox!.delete(personId);
    if (_currentPerson?.id == personId) {
      _currentPerson = null;
    }
    notifyListeners();
  }

  // Sensor Assignment Management
  Future<void> assignSensorToAthlete(String sensorId, String athleteId) async {
    // First, remove this sensor from any other athlete
    for (var person in _personBox!.values) {
      if (person.hasSensorAssigned(sensorId) && person.id != athleteId) {
        person.assignedSensorIds.remove(sensorId);
        await _personBox!.put(person.id, person);
      }
    }
    
    // Then assign to the target athlete
    final athlete = _personBox!.get(athleteId);
    if (athlete != null) {
      athlete.assignSensor(sensorId);
      await _personBox!.put(athleteId, athlete);
      notifyListeners();
    }
  }

  Future<void> unassignSensor(String sensorId) async {
    for (var person in _personBox!.values) {
      if (person.hasSensorAssigned(sensorId)) {
        person.assignedSensorIds.remove(sensorId);
        await _personBox!.put(person.id, person);
        notifyListeners();
        break;
      }
    }
  }

  Person? getAthleteForSensor(String sensorId) {
    for (var person in _personBox!.values) {
      if (person.hasSensorAssigned(sensorId)) {
        return person;
      }
    }
    return null;
  }

  List<Person> getAthletes() {
    return _personBox!.values.where((p) => p.role == 'athlete').toList();
  }

  Person? getPersonById(String personId) {
    return _personBox!.get(personId);
  }

  // Training Session Management
  Future<TrainingSession> createSession({
    required String title,
    required String trainingType,
    String? personId,
    String? notes,
  }) async {
    // Resolve target person: explicit param wins, else fall back to _currentPerson,
    // else auto-select the first person in the box.
    String? targetPersonId = personId;
    if (targetPersonId == null) {
      if (_currentPerson == null) {
        final persons = getAllPersons();
        if (persons.isEmpty) {
          throw Exception('Please create a person profile first');
        }
        _currentPerson = persons.first;
        debugPrint('Auto-selected person: ${_currentPerson!.name}');
      }
      targetPersonId = _currentPerson!.id;
    }

    final session = TrainingSession(
      id: const Uuid().v4(),
      personId: targetPersonId,
      title: title,
      startTime: DateTime.now(),
      duration: 0,
      trainingType: trainingType,
      heartRateData: [],
      synced: false,
      notes: notes,
    );

    await _sessionBox!.put(session.id, session);
    notifyListeners();
    return session;
  }

  Future<void> updateSession(TrainingSession session) async {
    await _sessionBox!.put(session.id, session);
    notifyListeners();
  }

  Future<void> endSession(String sessionId) async {
    final session = _sessionBox!.get(sessionId);
    if (session != null) {
      session.endTime = DateTime.now();
      session.duration = session.endTime!.difference(session.startTime).inSeconds;
      
      // Calculate statistics
      if (session.heartRateData.isNotEmpty) {
        final heartRates = session.heartRateData.map((d) => d.heartRate).toList();
        session.avgHeartRate = heartRates.reduce((a, b) => a + b) ~/ heartRates.length;
        session.maxHeartRate = heartRates.reduce((a, b) => a > b ? a : b);
        session.minHeartRate = heartRates.reduce((a, b) => a < b ? a : b);

        // Calorie calc uses the session's own person (not _currentPerson)
        // so multi-athlete recordings get correct per-person calories.
        final sessionPerson = _personBox?.get(session.personId) ?? _currentPerson;
        if (sessionPerson != null) {
          session.calories = _calculateCalories(
            avgHeartRate: session.avgHeartRate!,
            duration: session.duration,
            weight: sessionPerson.weight,
            age: sessionPerson.age,
            gender: sessionPerson.gender,
          );
        }
      }
      
      await updateSession(session);
    }
  }

  List<TrainingSession> getAllSessions() {
    return _sessionBox!.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  List<TrainingSession> getUnsyncedSessions() {
    // Only return complete sessions that can be synced (have endTime)
    return _sessionBox!.values
        .where((s) => !s.synced && s.endTime != null)
        .toList();
  }

  Future<void> deleteSession(String sessionId) async {
    await _sessionBox!.delete(sessionId);
    notifyListeners();
  }

  double _calculateCalories({
    required int avgHeartRate,
    required int duration,
    required double weight,
    required int age,
    required String gender,
  }) {
    // Using a simplified formula
    // Calories = ((Age × 0.2017) + (Weight × 0.1988) + (Heart Rate × 0.6309) — 55.0969) × Time / 4.184
    final durationMinutes = duration / 60;
    final genderOffset = gender.toLowerCase() == 'male' ? 0 : -20;
    
    final calories = ((age * 0.2017) + 
                      (weight * 0.1988) + 
                      (avgHeartRate * 0.6309) - 
                      55.0969 + 
                      genderOffset) * 
                     durationMinutes / 4.184;
    
    return calories.clamp(0, double.infinity);
  }

  /// Sync a training session to Supabase
  Future<bool> syncSessionToCloud(
    TrainingSession session,
    SupabaseRepository supabaseRepository,
  ) async {
    try {
      if (session.endTime == null) {
        debugPrint('Cannot sync incomplete session ${session.id}');
        return false;
      }

      debugPrint('Starting sync for session ${session.id}');
      
      // Prepare heart rate data
      final heartRateData = session.heartRateData
          .map((d) => {
                'timestamp': d.timestamp.toIso8601String(),
                'heartRate': d.heartRate,
                'deviceId': d.deviceId,
              })
          .toList();

      // Sync to Supabase
      await supabaseRepository.upsertTrainingSession(
        id: session.id,
        personId: session.personId,
        title: session.title,
        trainingType: session.trainingType,
        startTime: session.startTime,
        endTime: session.endTime!,
        duration: session.duration,
        avgHeartRate: session.avgHeartRate ?? 0,
        maxHeartRate: session.maxHeartRate ?? 0,
        minHeartRate: session.minHeartRate ?? 0,
        calories: session.calories ?? 0,
        heartRateData: heartRateData,
        notes: session.notes,
        rrIntervals: null, // Add if you capture RR intervals
      );

      debugPrint('Supabase upload successful for session ${session.id}');
      
      // Mark session as synced in local database
      session.synced = true;
      await _sessionBox!.put(session.id, session);
      
      debugPrint('Session ${session.id} marked as synced in local database');
      debugPrint('Session synced flag is now: ${session.synced}');
      
      return true;
    } catch (e) {
      debugPrint('Error syncing session to cloud: $e');
      return false;
    }
  }

  /// Pull persons and sessions from Supabase into local Hive
  Future<void> syncDownFromCloud(SupabaseRepository repo) async {
    try {
      // --- Persons ---
      final remotePersons = await repo.fetchPersons();
      debugPrint('[SyncDown] Fetched ${remotePersons.length} persons from cloud');
      for (final json in remotePersons) {
        final person = _personFromSupabase(json);
        // Preserve local sensor assignments
        final existing = _personBox!.get(person.id);
        if (existing != null) {
          person.assignedSensorIds = existing.assignedSensorIds;
        }
        await _personBox!.put(person.id, person);
      }

      // --- Sessions ---
      final remoteSessions = await repo.fetchSessions();
      debugPrint('[SyncDown] Fetched ${remoteSessions.length} sessions from cloud');
      for (final json in remoteSessions) {
        final session = _sessionFromSupabase(json);
        await _sessionBox!.put(session.id, session);
      }

      notifyListeners();
      debugPrint('[SyncDown] Sync down complete');
    } catch (e) {
      debugPrint('[SyncDown] Error: $e');
    }
  }

  Person _personFromSupabase(Map<String, dynamic> json) => Person(
    id: json['id'],
    name: json['name'] ?? '',
    age: json['age'] ?? 0,
    gender: json['gender'] ?? 'male',
    weight: (json['weight'] ?? 0.0).toDouble(),
    height: (json['height'] ?? 0.0).toDouble(),
    maxHeartRate: json['max_heart_rate'],
    restingHeartRate: json['resting_heart_rate'],
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    role: json['role'] ?? 'athlete',
    category: json['category'],
    group: json['group'],
  );

  TrainingSession _sessionFromSupabase(Map<String, dynamic> json) {
    List<HeartRateData> hrData = [];
    final raw = json['heart_rate_data'];
    if (raw != null) {
      final list = raw is String ? jsonDecode(raw) as List : raw as List;
      hrData = list.map((e) => HeartRateData.fromJson(e as Map<String, dynamic>)).toList();
    }
    return TrainingSession(
      id: json['id'],
      personId: json['person_id'] ?? '',
      title: json['title'] ?? '',
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      duration: json['duration'] ?? 0,
      avgHeartRate: json['avg_heart_rate'],
      maxHeartRate: json['max_heart_rate'],
      minHeartRate: json['min_heart_rate'],
      calories: json['calories']?.toDouble(),
      trainingType: json['training_type'] ?? '',
      heartRateData: hrData,
      synced: json['synced'] ?? true,
      notes: json['notes'],
    );
  }

  /// Sync all unsynced sessions to Supabase
  Future<int> syncAllUnsyncedSessions(
    SupabaseRepository supabaseRepository,
  ) async {
    try {
      final unsyncedSessions = getUnsyncedSessions();
      debugPrint('Found ${unsyncedSessions.length} unsynced sessions to upload');
      
      int syncedCount = 0;

      for (var session in unsyncedSessions) {
        debugPrint('Syncing session ${session.id}: synced=${session.synced}, endTime=${session.endTime}');
        final success = await syncSessionToCloud(session, supabaseRepository);
        if (success) {
          syncedCount++;
          debugPrint('Successfully synced session ${session.id}');
        } else {
          debugPrint('Failed to sync session ${session.id}');
        }
      }

      // Force notify listeners after all syncs complete
      if (syncedCount > 0) {
        debugPrint('Notifying listeners after syncing $syncedCount sessions');
        notifyListeners();
      }
      
      // Verify badge count after sync
      final remainingUnsynced = getUnsyncedSessions().length;
      debugPrint('After sync: $remainingUnsynced unsynced sessions remaining');
      
      return syncedCount;
    } catch (e) {
      debugPrint('Error syncing all unsynced sessions: $e');
      return 0;
    }
  }
}