import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/training_history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth_gate.dart';
import 'services/ble_service.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';
import 'services/sync_service.dart';
import 'services/auth_service.dart';
import 'supabase/supabase_client.dart';
import 'services/app_initializer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Start initialization in background and launch app immediately to keep UI responsive.
  // Errors during initialization will cause the initializer future to complete with error and
  // the UI will show an error screen if needed.
  runZonedGuarded(() {
    debugPrint('Starting non-blocking initialization...');

    // Kick off initialization (does not block)
    AppInitializer.instance.start();

    // Start the app immediately
    runApp(const MyApp());
  }, (error, stackTrace) {
    debugPrint('Unhandled error: $error');
    debugPrint('Stack trace: $stackTrace');
    runApp(ErrorApp(error: error.toString(), stackTrace: stackTrace.toString()));
  });
}

class ErrorApp extends StatelessWidget {
  final String error;
  final String stackTrace;

  const ErrorApp({super.key, required this.error, required this.stackTrace});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('App Error')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('App failed to initialize:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              const Text('Stack Trace:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(stackTrace, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => BLEService()),
        ChangeNotifierProvider(create: (_) => DatabaseService.instance),
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProvider(create: (_) => SettingsService.instance),
      ],
      child: MaterialApp(
        title: 'Linglong HR Monitor',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const AuthGate(child: _InitializerScreen()),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/history': (context) => const TrainingHistoryScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}

class _InitializerScreen extends StatelessWidget {
  const _InitializerScreen();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: AppInitializer.instance.initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a lightweight loading UI while services initialize
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Starting...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return ErrorApp(
            error: snapshot.error.toString(),
            stackTrace: snapshot.stackTrace?.toString() ?? '',
          );
        }

        // Initialization complete — show the home screen
        return const HomeScreen();
      },
    );
  }
}
