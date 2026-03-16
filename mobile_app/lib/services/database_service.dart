import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/person.dart';
import '../models/training_session.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService instance = DatabaseService._internal();
  
  Box<Person>? _personBox;
  Box<TrainingSession>? _sessionBox;
  
  Person? _currentPerson;
  
  DatabaseService._internal();

  Future<void> init() async {
    // Register adapters
    // Hive.registerAdapter(PersonAdapter());
    // Hive.registerAdapter(TrainingSessionAdapter());
    // Hive.registerAdapter(HeartRateDataAdapter());
    
    // Open boxes
    _personBox = await Hive.openBox<Person>('persons');
    _sessionBox = await Hive.openBox<TrainingSession>('training_sessions');
    
    // Load current person if exists
    if (_personBox!.isNotEmpty) {
      _currentPerson = _personBox!.values.first;
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
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await _personBox!.put(person.id, person);
    _currentPerson = person;
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

  // Training Session Management
  Future<TrainingSession> createSession({
    required String title,
    required String trainingType,
    String? notes,
  }) async {
    if (_currentPerson == null) {
      throw Exception('No person profile found');
    }

    final session = TrainingSession(
      id: const Uuid().v4(),
      personId: _currentPerson!.id,
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
        
        // Simple calorie calculation (can be improved)
        if (_currentPerson != null) {
          session.calories = _calculateCalories(
            avgHeartRate: session.avgHeartRate!,
            duration: session.duration,
            weight: _currentPerson!.weight,
            age: _currentPerson!.age,
            gender: _currentPerson!.gender,
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
    return _sessionBox!.values.where((s) => !s.synced).toList();
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
}
