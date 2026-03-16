import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/supabase_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _categoryController = TextEditingController();
  final _groupController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSigningIn = false;

  @override
  void dispose() {
    _categoryController.dispose();
    _groupController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showSignInDialog() async {
    _emailController.clear();
    _passwordController.clear();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In to Supabase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              final password = _passwordController.text;
              
              if (email.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }
              
              Navigator.pop(context);
              setState(() => _isSigningIn = true);
              
              try {
                final repo = SupabaseRepository();
                await repo.signIn(email, password);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed in successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign in failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isSigningIn = false);
                }
              }
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      final repo = SupabaseRepository();
      await repo.signOut();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository();
    final currentUser = repo.currentUser;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          final categories = settings.getCategories();
          final groups = settings.getGroups();
          final appInfo = settings.getAppInfo();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Supabase Auth Section
                const Text('Supabase Cloud Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              currentUser != null ? Icons.cloud_done : Icons.cloud_off,
                              color: currentUser != null ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentUser != null 
                                    ? 'Signed in as ${currentUser.email}'
                                    : 'Not signed in',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isSigningIn)
                          const Center(child: CircularProgressIndicator())
                        else if (currentUser != null)
                          ElevatedButton.icon(
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _showSignInDialog,
                            icon: const Icon(Icons.login),
                            label: const Text('Sign In'),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          currentUser != null
                              ? 'Your data will sync automatically to the cloud'
                              : 'Sign in to sync your data to Supabase cloud',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Divider(height: 32),
                const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .map((c) => Chip(label: Text(c), onDeleted: () => settings.deleteCategory(c)))
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _categoryController,
                        decoration: const InputDecoration(labelText: 'Add category'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final v = _categoryController.text.trim();
                        if (v.isNotEmpty) {
                          settings.addCategory(v);
                          _categoryController.clear();
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),

                const Divider(height: 32),
                const Text('Groups', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: groups
                      .map((g) => Chip(label: Text(g), onDeleted: () => settings.deleteGroup(g)))
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _groupController,
                        decoration: const InputDecoration(labelText: 'Add group'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final v = _groupController.text.trim();
                        if (v.isNotEmpty) {
                          settings.addGroup(v);
                          _groupController.clear();
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),

                const Divider(height: 32),
                const Text('Organization & Users', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Organization and user management is application-specific.\nUse the backend admin for advanced user/org tasks.'),

                const Divider(height: 32),
                const Text('App Info', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Version'),
                  subtitle: Text(appInfo['version'] ?? 'unknown'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final available = await settings.checkForUpdate();
                    if (!mounted) return;
                    if (available) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Update Available'),
                          content: const Text('A new app update is available.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                          ],
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App is up to date')));
                    }
                  },
                  child: const Text('Check for Update'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
