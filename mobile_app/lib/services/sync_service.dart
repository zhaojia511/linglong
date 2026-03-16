import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/person.dart';
import '../models/training_session.dart';
import 'database_service.dart';

class SyncService extends ChangeNotifier {
  static const String defaultBaseUrl = 'http://localhost:3000/api';
  String _baseUrl = defaultBaseUrl;
  String? _authToken;
  bool _isSyncing = false;
  Timer? _periodicSyncTimer;

  bool get isSyncing => _isSyncing;
  String get baseUrl => _baseUrl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_base_url') ?? defaultBaseUrl;
    _authToken = prefs.getString('auth_token');
    
    // Start periodic sync if authenticated
    if (_authToken != null) {
      _startPeriodicSync();
    }
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    // Periodic profile sync only (profiles can be edited on web)
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncAllPersons();
    });
    debugPrint('Periodic profile sync started (every 5 minutes)');
  }

  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    debugPrint('Periodic profile sync stopped');
  }

  @override
  void dispose() {
    _stopPeriodicSync();
    super.dispose();
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', url);
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _authToken!);
        
        _startPeriodicSync();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _stopPeriodicSync();
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  Future<bool> syncPerson(Person person) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/persons'),
        headers: _getHeaders(),
        body: jsonEncode(person.toJson()),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error syncing person: $e');
      return false;
    }
  }

  Future<int> syncAllPersons() async {
    if (_authToken == null) {
      debugPrint('Cannot sync persons: not authenticated');
      return 0;
    }

    try {
      final persons = DatabaseService.instance.getAllPersons();
      int syncedCount = 0;

      for (var person in persons) {
        final success = await syncPerson(person);
        if (success) {
          syncedCount++;
        }
      }

      debugPrint('Synced $syncedCount/${persons.length} profiles to backend');
      return syncedCount;
    } catch (e) {
      debugPrint('Error syncing all persons: $e');
      return 0;
    }
  }

  Future<bool> syncSession(TrainingSession session) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sessions'),
        headers: _getHeaders(),
        body: jsonEncode(session.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        session.synced = true;
        await DatabaseService.instance.updateSession(session);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error syncing session: $e');
      return false;
    }
  }

  Future<void> syncAll() async {
    if (_isSyncing || _authToken == null) return;

    _isSyncing = true;
    notifyListeners();

    try {
      // Sync all persons/profiles
      await syncAllPersons();

      // Sync unsynced sessions
      final unsyncedSessions = DatabaseService.instance.getUnsyncedSessions();
      for (var session in unsyncedSessions) {
        await syncSession(session);
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }


