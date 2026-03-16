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
    debugPrint('[AuthService] init — checking existing session...');
    _client.auth.onAuthStateChange.listen((data) {
      debugPrint('[AuthService] onAuthStateChange: event=${data.event}, hasSession=${data.session != null}');
      _user = data.session?.user;
      _loading = false;
      _error = null;
      notifyListeners();
    });

    final existing = _client.auth.currentSession;
    debugPrint('[AuthService] existing session: ${existing != null ? "yes (user=${existing.user.email})" : "none"}');
    _user = existing?.user;
    _loading = false;
    notifyListeners();
  }

  /// Sign in with email + password. Returns null on success, error message on failure.
  Future<String?> signIn(String email, String password) async {
    debugPrint('[AuthService] signIn: $email');
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      debugPrint('[AuthService] signIn success: user=${res.user?.email}, hasSession=${res.session != null}');
      return null;
    } on AuthException catch (e) {
      debugPrint('[AuthService] signIn AuthException: ${e.message}');
      _loading = false;
      _error = e.message;
      notifyListeners();
      return e.message;
    } catch (e) {
      debugPrint('[AuthService] signIn error: $e');
      _loading = false;
      _error = e.toString();
      notifyListeners();
      return e.toString();
    }
  }

  /// Sign up with email + password. Returns null on success, error message on failure.
  Future<String?> signUp(String email, String password) async {
    debugPrint('[AuthService] signUp: $email');
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      _loading = false;
      debugPrint('[AuthService] signUp result: user=${res.user?.email}, hasSession=${res.session != null}');
      if (res.user == null) {
        _error = 'Sign up failed';
        notifyListeners();
        return 'Sign up failed';
      }
      if (res.session == null) {
        debugPrint('[AuthService] signUp: email confirmation required');
        notifyListeners();
        return 'CHECK_EMAIL';
      }
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      debugPrint('[AuthService] signUp AuthException: ${e.message}');
      _loading = false;
      _error = e.message;
      notifyListeners();
      return e.message;
    } catch (e) {
      debugPrint('[AuthService] signUp error: $e');
      _loading = false;
      _error = e.toString();
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> signOut() async {
    debugPrint('[AuthService] signOut');
    await _client.auth.signOut();
  }
}
