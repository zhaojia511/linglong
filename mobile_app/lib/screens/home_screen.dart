import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/supabase_repository.dart';
import '../models/training_session.dart';
import '../screens/session_visualization_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'readiness_history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Keep screen instances persistent to maintain state across tab switches
  late final List<Widget> _screens = [
    const DashboardScreen(),
    const TrainingHistoryWidget(),
    const ReadinessHistoryScreen(),
    const ProfileScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: const [],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Readiness',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class TrainingHistoryWidget extends StatefulWidget {
  const TrainingHistoryWidget({super.key});

  @override
  State<TrainingHistoryWidget> createState() => _TrainingHistoryWidgetState();
}

class _TrainingHistoryWidgetState extends State<TrainingHistoryWidget> {
  bool _isMultiSelectMode = false;
  final Set<String> _selectedSessions = {};
  final Set<String> _syncingSessions = {};

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedSessions.clear();
      }
    });
  }

  void _toggleSessionSelection(String sessionId) {
    setState(() {
      if (_selectedSessions.contains(sessionId)) {
        _selectedSessions.remove(sessionId);
      } else {
        _selectedSessions.add(sessionId);
      }
    });
  }

  Future<void> _syncAllUnsynced(BuildContext context) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    
    // Check if there are any unsynced sessions
    final unsyncedSessions = dbService.getUnsyncedSessions();
    
    if (unsyncedSessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All sessions are synced'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Uploading ${unsyncedSessions.length} session(s)...'),
        duration: const Duration(seconds: 2),
      ),
    );
    
    try {
      final supabaseRepo = SupabaseRepository();
      
      // Check if user is authenticated
      if (supabaseRepo.currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to Supabase first'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Upload unsynced sessions to cloud
      final uploadedCount = await dbService.syncAllUnsyncedSessions(supabaseRepo);
      
      if (context.mounted) {
        // Force UI refresh to update badge count
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploadedCount > 0 
                ? 'Successfully uploaded $uploadedCount session(s)'
                : 'No sessions to upload'),
            backgroundColor: uploadedCount > 0 ? Colors.green : Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _syncSingleSession(BuildContext context, TrainingSession session) async {
    if (session.synced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session already synced'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Prevent double-sync
    if (_syncingSessions.contains(session.id)) {
      return;
    }
    
    setState(() {
      _syncingSessions.add(session.id);
    });
    
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    
    try {
      final supabaseRepo = SupabaseRepository();
      
      // Check if user is authenticated
      if (supabaseRepo.currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to Supabase first'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      final success = await dbService.syncSessionToCloud(session, supabaseRepo);
      
      if (context.mounted) {
        setState(() {}); // Force UI refresh
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Session synced successfully' : 'Sync failed'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingSessions.remove(session.id);
        });
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, DatabaseService dbService, List<String> sessionIds, bool isMultiple) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session(s)'),
        content: Text(
          isMultiple
              ? 'Are you sure you want to delete ${sessionIds.length} selected sessions?'
              : 'Are you sure you want to delete this session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              for (var sessionId in sessionIds) {
                dbService.deleteSession(sessionId);
              }
              Navigator.pop(context);
              
              setState(() {
                _isMultiSelectMode = false;
                _selectedSessions.clear();
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isMultiple
                        ? '${sessionIds.length} sessions deleted'
                        : 'Session deleted',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isMultiSelectMode
              ? 'Select Sessions (${_selectedSessions.length})'
              : 'Training History',
        ),
        actions: [
          Consumer<DatabaseService>(
            builder: (context, dbService, child) {
              final unsyncedCount = dbService.getUnsyncedSessions().length;
              return unsyncedCount > 0
                  ? IconButton(
                      icon: Badge(
                        label: Text('$unsyncedCount'),
                        child: const Icon(Icons.cloud_upload),
                      ),
                      onPressed: () => _syncAllUnsynced(context),
                    )
                  : const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: Icon(_isMultiSelectMode ? Icons.close : Icons.select_all),
            onPressed: _toggleMultiSelectMode,
          ),
          if (_isMultiSelectMode && _selectedSessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                _showDeleteConfirmation(
                  context,
                  Provider.of<DatabaseService>(context, listen: false),
                  _selectedSessions.toList(),
                  true,
                );
              },
            ),
        ],
      ),
      body: Consumer<DatabaseService>(
        builder: (context, dbService, child) {
          final sessions = dbService.getAllSessions();

          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No training sessions yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isSelected = _selectedSessions.contains(session.id);

              return Dismissible(
                key: Key(session.id),
                background: Container(
                  color: Colors.red.shade400,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Session'),
                      content: const Text('Are you sure you want to delete this session?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  return result ?? false;
                },
                onDismissed: (direction) {
                  dbService.deleteSession(session.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session deleted'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: isSelected ? Colors.blue.shade50 : null,
                  child: ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: _isMultiSelectMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (_) =>
                                _toggleSessionSelection(session.id),
                          )
                        : CircleAvatar(
                            radius: 16,
                            child: Icon(_getTrainingIcon(session.trainingType),
                                size: 16),
                          ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Show athlete name if available
                        Consumer<DatabaseService>(
                          builder: (context, dbService, child) {
                            final person = dbService.getPersonById(session.personId);
                            if (person != null) {
                              return Text(
                                person.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${_formatDuration(session.duration)} • ${session.startTime.toString().substring(0, 16)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: _isMultiSelectMode
                        ? null
                        : _syncingSessions.contains(session.id)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: Icon(
                                  session.synced ? Icons.cloud_done : Icons.cloud_upload,
                                  color: session.synced ? Colors.green : Colors.orange,
                                  size: 20,
                                ),
                                onPressed: session.synced ? null : () => _syncSingleSession(context, session),
                                tooltip: session.synced ? 'Synced' : 'Tap to upload',
                              ),
                    onTap: () {
                      if (_isMultiSelectMode) {
                        _toggleSessionSelection(session.id);
                      } else {
                        // Navigate to visualization screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SessionVisualizationScreen(session: session),
                          ),
                        );
                      }
                    },
                    onLongPress: () {
                      if (!_isMultiSelectMode) {
                        setState(() {
                          _isMultiSelectMode = true;
                          _selectedSessions.add(session.id);
                        });
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getTrainingIcon(String type) {
    switch (type.toLowerCase()) {
      case 'running':
        return Icons.directions_run;
      case 'cycling':
        return Icons.directions_bike;
      case 'gym':
        return Icons.fitness_center;
      default:
        return Icons.sports;
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m ${secs}s';
    }
  }
}
