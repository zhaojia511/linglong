import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Set these from env/secure storage; do not hardcode secrets.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://krbobzpwgzxhnqssgwoy.supabase.co');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtyYm9ienB3Z3p4aG5xc3Nnd295Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcyNDM1OTEsImV4cCI6MjA4MjgxOTU5MX0.4z4gEpUdVahjHfmSCiyTEaPS_vWljX9zzjKSi_Gm99E');
}

class SupabaseClientProvider {
  static late SupabaseClient _client;

  static SupabaseClient get client => _client;

  static Future<void> init() async {
    debugPrint('[Supabase] Initializing with URL: ${SupabaseConfig.supabaseUrl}');
    try {
      if (Supabase.instance.client.auth.currentUser != null) {
        debugPrint('[Supabase] Already initialized, reusing client');
        _client = Supabase.instance.client;
        return;
      }
    } catch (_) {
      // Not initialized yet, proceed with initialization
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      debugPrint('[Supabase] Initialized successfully');
    } catch (e) {
      debugPrint('[Supabase] Init FAILED: $e');
      rethrow;
    }
  }
}
