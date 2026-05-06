import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/supabase_repository.dart';
import '../services/auth_service.dart';
import 'help_screen.dart';

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
      await context.read<AuthService>().signOut();
      
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
      appBar: AppBar(title: null),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          final categories = settings.getCategories();
          final groups = settings.getGroups();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Cloud Sync (compact, sign-out on the right) ──────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          currentUser != null ? Icons.cloud_done : Icons.cloud_off,
                          size: 18,
                          color: currentUser != null ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentUser != null
                                ? currentUser.email ?? 'Signed in'
                                : 'Not signed in — data saved locally',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isSigningIn)
                          const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                        else if (currentUser != null)
                          TextButton.icon(
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout, size: 14),
                            label: const Text('Sign out', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 8)),
                          )
                        else
                          TextButton.icon(
                            onPressed: _showSignInDialog,
                            icon: const Icon(Icons.login, size: 14),
                            label: const Text('Sign in', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8)),
                          ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 28),

                // ── Categories & Groups side by side as drop-lists ────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _TagColumn(
                      label: 'Categories',
                      items: categories,
                      controller: _categoryController,
                      onAdd: () {
                        final v = _categoryController.text.trim();
                        if (v.isNotEmpty) { settings.addCategory(v); _categoryController.clear(); }
                      },
                      onDelete: settings.deleteCategory,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _TagColumn(
                      label: 'Groups',
                      items: groups,
                      controller: _groupController,
                      onAdd: () {
                        final v = _groupController.text.trim();
                        if (v.isNotEmpty) { settings.addGroup(v); _groupController.clear(); }
                      },
                      onDelete: settings.deleteGroup,
                    )),
                  ],
                ),

                const Divider(height: 28),

                // ── App Info ──────────────────────────────────────────────
                if (settings.pendingUpdate != null)
                  _UpdateBanner(update: settings.pendingUpdate!),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16),
                    const SizedBox(width: 6),
                    const Text('Version  $kAppVersion (build $kAppBuildNumber)',
                        style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Check', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final update = await settings.checkForUpdate();
                        if (!mounted) return;
                        if (update == null) {
                          messenger.showSnackBar(
                              const SnackBar(content: Text('App is up to date')));
                        }
                      },
                    ),
                  ],
                ),

                const Divider(height: 28),

                // ── Help ──────────────────────────────────────────────────
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.help_outline, size: 20),
                  title: const Text('Help', style: TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  dense: true,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HelpScreen())),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TagColumn extends StatelessWidget {
  final String label;
  final List<String> items;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final void Function(String) onDelete;

  const _TagColumn({
    required this.label,
    required this.items,
    required this.controller,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        // Drop-list style container
        Container(
          constraints: const BoxConstraints(minHeight: 36, maxHeight: 120),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: items.isEmpty
              ? Center(
                  child: Text('None', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  children: items.map((item) => SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
                        IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          color: Colors.grey[500],
                          onPressed: () => onDelete(item),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add…',
                  hintStyle: const TextStyle(fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('+'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  final UpdateInfo update;
  const _UpdateBanner({required this.update});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: update.isForced ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: update.isForced ? Colors.red.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              update.isForced ? Icons.warning_amber : Icons.system_update,
              color: update.isForced ? Colors.red : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    update.isForced
                        ? 'Update required — v${update.latestVersion}'
                        : 'Update available — v${update.latestVersion}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: update.isForced ? Colors.red.shade800 : Colors.orange.shade800,
                    ),
                  ),
                  if (update.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(update.releaseNotes,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    update.isForced
                        ? 'This version is no longer supported. Please update to continue.'
                        : 'Build the latest version from source and install it.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
