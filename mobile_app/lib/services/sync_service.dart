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

  bool get isSyncing => _isSyncing;
  String get baseUrl => _baseUrl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_base_url') ?? defaultBaseUrl;
    _authToken = prefs.getString('auth_token');
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
      // Sync current person
      final person = DatabaseService.instance.currentPerson;
      if (person != null) {
        await syncPerson(person);
      }

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

  Future<List<TrainingSession>> fetchSessions({int? limit, int? offset}) async {
    try {
      final uri = Uri.parse('$_baseUrl/sessions').replace(
        queryParameters: {
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
        },
      );

      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => TrainingSession.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
      return [];
    }
  }

  bool get isAuthenticated => _authToken != null;
}
