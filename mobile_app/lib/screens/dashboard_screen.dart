import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/ble_service.dart';
import '../services/database_service.dart';
import '../services/supabase_repository.dart';
import '../models/training_session.dart';
import '../models/hr_device.dart';
import '../models/person.dart';

// Data point for heart rate with timestamp
class HeartRateDataPoint {
  final DateTime timestamp;
  final double value;

  HeartRateDataPoint({
    required this.timestamp,
    required this.value,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  TrainingSession? _activeSession;
  Timer? _recordTimer;
  bool _isSyncing = false;
  bool _bleEnabled = true;
  late Timer _bleCheckTimer;
  final Map<String, List<HeartRateDataPoint>> _heartRateHistoryByDevice = {};

  @override
  void initState() {
    super.initState();
    // Attempt to restore previously connected devices instead of resetting
    final bleService = Provider.of<BLEService>(context, listen: false);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Restore previously connected devices
        await bleService.autoReconnectToSavedDevices();
        
        await _checkBluetoothStatus();
        final updatedBleService = Provider.of<BLEService>(context, listen: false);
        await updatedBleService.checkPermissions(); // Check permissions on startup
        
        // Only start scanning if permissions are granted and no devices already connected
        if (updatedBleService.permissionsGranted) {
          if (updatedBleService.connectedDevices.isEmpty) {
            final error = await updatedBleService.startScan();
            if (error != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else {
            debugPrint('Devices already connected, skipping scan');
          }
        }
      } catch (e) {
        debugPrint('Error in dashboard init: $e');
      }
    });
    
    // Check Bluetooth status every 2 seconds
    _bleCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _checkBluetoothStatus();
      }
    });
  }

  Future<void> _checkBluetoothStatus() async {
    try {
      final bleService = Provider.of<BLEService>(context, listen: false);
      final available = await bleService.isBluetoothAvailable();
      if (mounted) {
        setState(() {
          _bleEnabled = available;
        });
      }
    } catch (e) {
      debugPrint('Error checking Bluetooth status: $e');
      if (mounted) {
        setState(() {
          _bleEnabled = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _bleCheckTimer.cancel();
    super.dispose();
  }

  void _startRecording() async {
    debugPrint('=== _startRecording called ===');
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      debugPrint('DatabaseService obtained');

      final session = await dbService.createSession(
        title: 'Training Session ${DateTime.now().toString().substring(0, 16)}',
        trainingType: 'general',
      );
      debugPrint('Session created: ${session.id}');

      setState(() {
        _activeSession = session;
        _heartRateHistoryByDevice.clear();
      });
      debugPrint('State updated, activeSession set');

      // Record heart rate every second
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final bleService = Provider.of<BLEService>(context, listen: false);

        // Record data for each connected device
        for (var device in bleService.connectedDevices) {
          if (device.currentHeartRate != null) {
            final hrData = HeartRateData(
              timestamp: DateTime.now(),
              heartRate: device.currentHeartRate!,
              deviceId: device.id,
            );

            _activeSession!.heartRateData.add(hrData);

            // Store in device-specific history
            _heartRateHistoryByDevice.putIfAbsent(device.id, () => []);
            _heartRateHistoryByDevice[device.id]!.add(
              HeartRateDataPoint(
                timestamp: DateTime.now(),
                value: device.currentHeartRate!.toDouble(),
              ),
            );

            setState(() {});
          }
        }
      });
      debugPrint('Timer started');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Training session started'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR in _startRecording: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start training: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _stopRecording() async {
    _recordTimer?.cancel();

    if (_activeSession != null) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.endSession(_activeSession!.id);

      // Sync session to Supabase in background
      _syncSessionToCloud(_activeSession!);

      setState(() {
        _activeSession = null;
        _heartRateHistoryByDevice.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Training session saved and syncing to cloud...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _syncSessionToCloud(TrainingSession session) async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final supabaseRepository = SupabaseRepository();

      final success =
          await dbService.syncSessionToCloud(session, supabaseRepository);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session synced to cloud successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Session saved locally (sync will retry later)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error during cloud sync: $e');
      if (mounted) {
        // Only show error if it's not a typical initialization issue
        String errorMsg = 'Session saved locally (sync unavailable)';
        if (!e.toString().contains('_isInitialized')) {
          errorMsg = 'Session saved locally (sync failed)';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HR Monitor',
          style: TextStyle(fontSize: 16),
        ),
        toolbarHeight: 48,
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth, size: 20),
            onPressed: () => _showDeviceDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Bluetooth permissions warning banner
          Consumer<BLEService>(
            builder: (context, bleService, child) {
              if (!bleService.permissionsGranted) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.orange.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bluetooth permissions required. On iOS, you must enable Bluetooth permissions in Settings > Privacy & Security > Bluetooth.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          debugPrint('Grant button pressed');
                          // On iOS, open settings directly since permissions can't be requested programmatically
                          // For now, just show the guidance message
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please go to Settings > Privacy & Security > Bluetooth and enable permissions for Linglong HR Monitor.'),
                                backgroundColor: Colors.blue,
                                duration: Duration(seconds: 8),
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Grant',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Bluetooth disabled warning banner
          if (!_bleEnabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bluetooth is disabled. Please enable Bluetooth to connect sensors.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Main content
          Expanded(
            child: Consumer<BLEService>(
              builder: (context, bleService, child) {
                final connectedDevices = bleService.connectedDevices;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                // Team Overview Card - Compact
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Connected',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${connectedDevices.where((d) => d.isConnected).length}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.devices_other,
                          color: Colors.blue[300],
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Grid of Device Cards
                if (connectedDevices.where((d) => d.isConnected).isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.bluetooth_disabled,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No devices connected',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the Bluetooth icon to scan for devices',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio:
                          0.95, // Original sizing for smaller cards
                    ),
                    itemCount: connectedDevices.where((d) => d.isConnected).length + 3,
                    itemBuilder: (context, index) {
                      final connectedOnly = connectedDevices.where((d) => d.isConnected).toList();
                      
                      if (index < connectedOnly.length) {
                        final device = connectedOnly[index];
                        final athlete = DatabaseService.instance.getAthleteForSensor(device.id);
                        return _buildSquareDeviceCard(device, index + 1, athlete);
                      } else {
                        // Show mock BPM data cards
                        final mockIndex = index - connectedOnly.length;
                        return _buildMockBPMCard(mockIndex + 1, connectedOnly.length + mockIndex + 1);
                      }
                    },
                  ),

                const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<BLEService>(
        builder: (context, bleService, child) {
          final connectedDevices = bleService.connectedDevices.where((d) => d.isConnected).toList();
          debugPrint('FAB check: _activeSession=${_activeSession != null}, connectedCount=${connectedDevices.length}');
          
          VoidCallback? onPressed;
          if (_activeSession == null && connectedDevices.isNotEmpty) {
            onPressed = () {
              debugPrint('Starting recording...');
              _startRecording();
            };
          } else if (_activeSession != null) {
            onPressed = () {
              debugPrint('Stopping recording...');
              _stopRecording();
            };
          } else {
            debugPrint('FAB disabled: no connected devices');
          }
          
          return FloatingActionButton.extended(
            heroTag: 'dashboard_fab',
            onPressed: onPressed,
            icon: Icon(_activeSession == null ? Icons.play_arrow : Icons.stop),
            label: Text(
                _activeSession == null ? 'Start Training' : 'Stop Training'),
            backgroundColor: _activeSession == null ? Colors.green : Colors.red,
          );
        },
      ),
    );
  }

  Widget _buildSquareDeviceCard(HRDevice device, int memberNumber, Person? athlete) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getColorForMember(memberNumber).withOpacity(0.12),
              _getColorForMember(memberNumber).withOpacity(0.04),
            ],
          ),
        ),
        child: InkWell(
          onTap: () => _showSensorAssignmentDialog(context, device, athlete),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top: Athlete name or Member ID
                Text(
                  athlete?.name ?? 'Tap to assign',
                  style: TextStyle(
                    fontSize: athlete != null ? 9 : 7,
                    color: athlete != null ? Colors.blue[700] : Colors.grey[500],
                    fontWeight: athlete != null ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),

                // Main: Large Heart Rate Display (fills most space)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _getHeartRateColorByTrainingZone(device.currentHeartRate)
                          .withOpacity(0.95),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          device.currentHeartRate?.toString() ?? '--',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const Text(
                          'bpm',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getTrainingZoneName(device.currentHeartRate),
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),

                // Bottom: Battery indicator (if available)
                if (device.batteryLevel != null)
                  Text(
                    '🔋 ${device.batteryLevel}%',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorForMember(int memberNumber) {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo
    ];
    return colors[(memberNumber - 1) % colors.length];
  }

  /// Gets color based on training zones (more detailed than basic HR color)
  /// Zone 1 (Recovery): < 120 bpm - Light blue
  /// Zone 2 (Aerobic): 120-150 bpm - Green
  /// Zone 3 (Tempo): 150-170 bpm - Yellow/Orange
  /// Zone 4 (Threshold): 170-190 bpm - Orange
  /// Zone 5 (Anaerobic): >= 190 bpm - Red
  Color _getHeartRateColorByTrainingZone(int? heartRate) {
    if (heartRate == null) return Colors.grey[600]!;
    if (heartRate < 120) return const Color(0xFF1E88E5); // Light blue - Recovery
    if (heartRate < 150) return const Color(0xFF43A047); // Green - Aerobic
    if (heartRate < 170) return const Color(0xFFFFB300); // Amber - Tempo
    if (heartRate < 190) return const Color(0xFFF4511E); // Deep Orange - Threshold
    return const Color(0xFFE53935); // Red - Anaerobic
  }

  String _getTrainingZoneName(int? heartRate) {
    if (heartRate == null) return 'Rest';
    if (heartRate < 120) return 'Recovery';
    if (heartRate < 150) return 'Aerobic';
    if (heartRate < 170) return 'Tempo';
    if (heartRate < 190) return 'Threshold';
    return 'Anaerobic';
  }

  void _showSensorAssignmentDialog(BuildContext context, HRDevice device, Person? currentAthlete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Sensor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sensor: ${device.name}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            if (currentAthlete != null)
              Text(
                'Currently assigned to: ${currentAthlete.name}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            const SizedBox(height: 16),
            const Text(
              'Assign to:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildAthleteList(device),
          ],
        ),
        actions: [
          if (currentAthlete != null)
            TextButton(
              onPressed: () async {
                await DatabaseService.instance.unassignSensor(device.id);
                if (context.mounted) Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Unassign', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Build a mock BPM card for demonstration/testing purposes
  /// Displays simulated heart rate data with training zone colors
  Widget _buildMockBPMCard(int mockDataIndex, int memberNumber) {
    // Mock data with different BPM values for different training zones
    final mockDataList = [
      {'name': 'Mock 1', 'bpm': 85, 'athlete': 'Demo Athlete 1'},
      {'name': 'Mock 2', 'bpm': 135, 'athlete': 'Demo Athlete 2'},
      {'name': 'Mock 3', 'bpm': 175, 'athlete': 'Demo Athlete 3'},
    ];
    
    final mockData = mockDataList[(mockDataIndex - 1) % mockDataList.length];
    final bpm = mockData['bpm'] as int;
    final name = mockData['athlete'] as String;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getColorForMember(memberNumber).withOpacity(0.12),
              _getColorForMember(memberNumber).withOpacity(0.04),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top: Athlete name
              Text(
                name,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),

              // Main: Large Heart Rate Display
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _getHeartRateColorByTrainingZone(bpm)
                        .withOpacity(0.95),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bpm.toString(),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const Text(
                        'bpm',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getTrainingZoneName(bpm),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom: Mock indicator
              Text(
                '📊 Demo',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAthleteList(HRDevice device) {
    final athletes = DatabaseService.instance.getAthletes();
    
    if (athletes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No athletes found. Add athletes in the Team Members tab.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      );
    }
    
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          children: athletes.map((athlete) {
            final isAssigned = athlete.hasSensorAssigned(device.id);
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: _getColorForAthlete(athlete),
                child: Text(
                  athlete.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              title: Text(
                athlete.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isAssigned ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                '${athlete.age}y, ${athlete.gender}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: isAssigned
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                  : null,
              onTap: () async {
                await DatabaseService.instance.assignSensorToAthlete(
                  device.id,
                  athlete.id,
                );
                if (context.mounted) Navigator.pop(context);
                setState(() {});
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getColorForAthlete(Person athlete) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    return colors[athlete.name.hashCode % colors.length];
  }

  void _showDeviceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DeviceDialog(),
    );
  }
}

class DeviceDialog extends StatefulWidget {
  const DeviceDialog({super.key});

  @override
  State<DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<DeviceDialog> {
  final Set<String> _connectingDevices = {};
  bool _bleAvailable = true;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Don't reset BLE service - preserve connected devices
      final bleService = Provider.of<BLEService>(context, listen: false);
      
      await _checkBluetoothAvailability();
      await bleService.checkPermissions(); // Check permissions on startup
      final error = await bleService.startScan();
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _checkBluetoothAvailability() async {
    final bleService = Provider.of<BLEService>(context, listen: false);
    final available = await bleService.isBluetoothAvailable();
    setState(() {
      _bleAvailable = available;
    });
  }

  Future<void> _handleRescan() async {
    final bleService = Provider.of<BLEService>(context, listen: false);
    final error = await bleService.startScan();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    setState(() {
      _hasScanned = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bluetooth Devices'),
      content: SizedBox(
        width: double.maxFinite,
        child: Consumer<BLEService>(
          builder: (context, bleService, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bluetooth availability warning
                if (!_bleAvailable)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bluetooth is not enabled. Please enable Bluetooth in device settings.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Connected: ${bleService.connectedDevices.length}/10',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (bleService.isScanning)
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton(
                        onPressed: _handleRescan,
                        child: Text(_hasScanned ? 'Rescan' : 'Scan'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (bleService.isScanning)
                  const LinearProgressIndicator()
                else
                  const SizedBox(height: 4),
                const SizedBox(height: 12),
                Flexible(
                  child: Column(
                    children: [
                      // Discovered devices list
                      Expanded(
                        child: bleService.discoveredDevices.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.bluetooth_disabled,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      bleService.isScanning
                                          ? 'Scanning for devices...'
                                          : _bleAvailable
                                              ? 'No devices found'
                                              : 'Bluetooth is disabled',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: bleService.discoveredDevices.length,
                                itemBuilder: (context, index) {
                                  final device = bleService.discoveredDevices[index];
                            final isConnected = device.isConnected;
                            final isConnecting =
                                _connectingDevices.contains(device.id);

                            return ListTile(
                              leading: const Icon(Icons.bluetooth),
                              title: Text(device.name),
                              subtitle:
                                  Text('Signal: ${device.rssi} dBm'),
                              trailing: isConnected
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : bleService.connectedDevices.length >= 10
                                      ? const Tooltip(
                                          message: 'Max devices connected',
                                          child: Icon(Icons.lock, color: Colors.grey),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ElevatedButton(
                                              onPressed: isConnecting
                                                  ? null
                                                  : () async {
                                                      setState(() {
                                                        _connectingDevices.add(device.id);
                                                      });

                                                      try {
                                                        final success = await bleService.connectDevice(device);
                                                        if (mounted) {
                                                          if (success) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('Connected to ${device.name}')),
                                                            );
                                                          } else {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Text('Failed to connect to ${device.name}'),
                                                                backgroundColor: Colors.red,
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      } finally {
                                                        setState(() {
                                                          _connectingDevices.remove(device.id);
                                                        });
                                                      }
                                                    },
                                              child: isConnecting
                                                  ? const SizedBox(
                                                      height: 16,
                                                      width: 16,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                  : const Text('Connect'),
                                            ),
                                            const SizedBox(width: 0),
                                          ],
                                        ),
                            );
                                },
                              ),
                      ),

                      const SizedBox(height: 8),
                      // Saved devices (previously connected) - useful when sensor doesn't advertise
                      FutureBuilder<List<HRDevice>>(
                        future: Provider.of<BLEService>(context, listen: false).getSavedConnectedDevices(),
                        builder: (context, snap) {
                          if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
                          
                          // Filter out devices that are already discovered or connected
                          final savedDevices = snap.data!
                              .where((sd) => !bleService.discoveredDevices.any((d) => d.id == sd.id) &&
                                            !bleService.connectedDevices.any((d) => d.id == sd.id))
                              .toList();
                          
                          if (savedDevices.isEmpty) return const SizedBox.shrink();
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Saved Devices', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: (savedDevices.length * 56).toDouble().clamp(0, 200),
                                child: ListView.builder(
                                  itemCount: savedDevices.length,
                                  itemBuilder: (context, i) {
                                    final sd = savedDevices[i];
                                    final isConnecting = _connectingDevices.contains(sd.id);
                                    return ListTile(
                                      leading: const Icon(Icons.history, color: Colors.grey),
                                      title: Text(sd.name, style: const TextStyle(fontSize: 12)),
                                      subtitle: Text(sd.id, style: const TextStyle(fontSize: 10)),
                                      trailing: ElevatedButton(
                                        onPressed: isConnecting
                                            ? null
                                            : () async {
                                                setState(() { _connectingDevices.add(sd.id); });
                                                try {
                                                  final success = await Provider.of<BLEService>(context, listen: false).connectDevice(sd);
                                                  if (mounted) {
                                                    if (success) {
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored ${sd.name}')));
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to restore ${sd.name}'), backgroundColor: Colors.red));
                                                    }
                                                  }
                                                } finally {
                                                  setState(() { _connectingDevices.remove(sd.id); });
                                                }
                                              },
                                        child: isConnecting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Restore', style: TextStyle(fontSize: 11)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        Consumer<BLEService>(
          builder: (context, bleService, child) {
            return TextButton(
              onPressed: bleService.connectedDevices.isEmpty
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Disconnect All Devices?'),
                          content: Text(
                            'This will disconnect ${bleService.connectedDevices.length} device(s).',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                bleService.disconnectAllDevices();
                                Navigator.pop(context);
                              },
                              child: const Text('Disconnect All',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
              child: const Text('Disconnect All'),
            );
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
