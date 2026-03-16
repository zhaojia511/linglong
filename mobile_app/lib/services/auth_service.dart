import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  bool _loading = true;
  String? _error;

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  SupabaseClient get _client => Supabase.instance.client;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    _client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      _loading = false;
      _error = null;
      notifyListeners();
    });

    final existing = _client.auth.currentSession;
    _user = existing?.user;
    _loading = false;
    notifyListeners();
  }

  /// Sign in with email + password. Returns null on success, error message on failure.
  Future<String?> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      _loading = false;
      _error = e.message;
      notifyListeners();
      return e.message;
    } catch (e) {
      _loading = false;
      _error = e.toString();
      notifyListeners();
      return e.toString();
    }
  }

  /// Sign up with email + password. Returns null on success, error message on failure.
  Future<String?> signUp(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (res.user == null) {
        _loading = false;
        _error = 'Sign up failed';
        notifyListeners();
        return 'Sign up failed';
      }
      return null;
    } on AuthException catch (e) {
      _loading = false;
      _error = e.message;
      notifyListeners();
      return e.message;
    } catch (e) {
      _loading = false;
      _error = e.toString();
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
