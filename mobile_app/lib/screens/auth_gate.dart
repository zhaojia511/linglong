import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';

/// Sits at the root of the widget tree and routes to either the login screen
/// or the authenticated app shell, based on [AuthService] state.
class AuthGate extends StatefulWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<void>? _syncInitFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthService>();
    if (auth.isAuthenticated && _syncInitFuture == null) {
      final sync = context.read<SyncService>();
      _syncInitFuture = sync.ensureInitialized();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.isAuthenticated) {
      return widget.child;
    }

    return const LoginScreen();
  }
}
