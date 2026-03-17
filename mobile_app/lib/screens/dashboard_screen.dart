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

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  TrainingSession? _activeSession;
  Timer? _recordTimer;
  bool _isSyncing = false;
  bool _bleEnabled = true;
  Timer? _bleCheckTimer;

  final Map<String, List<HeartRateDataPoint>> _heartRateHistoryByDevice = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final bleService = Provider.of<BLEService>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await bleService.autoReconnectToSavedDevices();

        await _checkBluetoothStatus();
        final updatedBleService = Provider.of<BLEService>(context, listen: false);
        await updatedBleService.checkPermissions();

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

    _startBleCheckTimer();
  }

  void _startBleCheckTimer() {
    _bleCheckTimer?.cancel();
    // Check BLE status every 30s — it rarely changes, no need to poll aggressively
    _bleCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _checkBluetoothStatus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App went to background — stop polling and scanning to save battery
      _bleCheckTimer?.cancel();
      _bleCheckTimer = null;
      final bleService = Provider.of<BLEService>(context, listen: false);
      if (bleService.isScanning) bleService.stopScan();
    } else if (state == AppLifecycleState.resumed) {
      // App came back to foreground — resume polling and check BLE status
      _startBleCheckTimer();
      _checkBluetoothStatus();
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _bleCheckTimer?.cancel();
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
        title: null,
        toolbarHeight: 28,
        leading: Consumer<BLEService>(
          builder: (context, bleService, _) {
            final count = bleService.connectedDevices.where((d) => d.isConnected).length;
            return InkWell(
              onTap: () => _showDeviceDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bluetooth, size: 20),
                    if (count > 0) ...[
                      const SizedBox(width: 3),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
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
          // Main content — full-screen grid
          Expanded(
            child: Consumer<BLEService>(
              builder: (context, bleService, child) {
                final connected = bleService.connectedDevices
                    .where((d) => d.isConnected)
                    .toList();

                // Portrait: 4 cols × 5 rows | Landscape: 5 cols × 4 rows = 20 slots
                // Cards are always square (childAspectRatio = 1.0)
                const gap = 4.0;
                const outerPad = 4.0;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isLandscape = constraints.maxWidth > constraints.maxHeight;
                    final cols = isLandscape ? 5 : 4;
                    final rows = isLandscape ? 4 : 5;
                    final totalSlots = cols * rows;

                    // Card size = 75% of available space, keeping square
                    final availW = constraints.maxWidth - outerPad * 2 - (cols - 1) * gap;
                    final availH = constraints.maxHeight - outerPad * 2 - (rows - 1) * gap;
                    final cellSize = ((availW / cols).clamp(0.0, availH / rows)) * 0.75;
                    final aspectRatio = cellSize / (availH / rows);

                    return GridView.builder(
                      padding: const EdgeInsets.all(outerPad),
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                        childAspectRatio: aspectRatio,
                      ),
                      itemCount: totalSlots,
                      itemBuilder: (context, index) {
                        if (index < connected.length) {
                          final device = connected[index];
                          final athlete = DatabaseService.instance
                              .getAthleteForSensor(device.id);
                          return _buildSquareDeviceCard(device, index + 1, athlete);
                        }
                        return _buildEmptySlot(index + 1);
                      },
                    );
                  },
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

  Widget _buildEmptySlot(int slotNumber) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      color: Colors.grey.withValues(alpha: 0.08),
      child: Center(
        child: Text(
          '$slotNumber',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.withValues(alpha: 0.3),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSquareDeviceCard(HRDevice device, int memberNumber, Person? athlete) {
    final zoneColor = _getHeartRateColorByTrainingZone(device.currentHeartRate);
    final accentColor = _getColorForMember(memberNumber);

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showSensorAssignmentDialog(context, device, athlete),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final w = constraints.maxWidth;
            // Scale fonts relative to card size
            final nameFontSize = (h * 0.09).clamp(8.0, 16.0);
            final bpmFontSize = (h * 0.38).clamp(24.0, 80.0);
            final labelFontSize = (h * 0.07).clamp(7.0, 14.0);
            final iconSize = (h * 0.14).clamp(12.0, 30.0);

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: zoneColor,
              ),
              child: Stack(
                children: [
                  // Subtle accent tint top-left corner
                  Positioned(
                    top: 0, left: 0,
                    child: Container(
                      width: w * 0.4,
                      height: h * 0.3,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomRight: Radius.circular(40),
                        ),
                        color: accentColor.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  // Card content
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: w * 0.05, vertical: h * 0.05),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Athlete name / assign prompt
                        Text(
                          athlete?.name ?? 'Tap to assign',
                          style: TextStyle(
                            fontSize: nameFontSize,
                            color: athlete != null
                                ? Colors.white
                                : Colors.white60,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),

                        // BPM value — centre, dominant
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite,
                                color: Colors.white70, size: iconSize),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                device.currentHeartRate?.toString() ?? '--',
                                style: TextStyle(
                                  fontSize: bpmFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            Text(
                              'bpm',
                              style: TextStyle(
                                fontSize: labelFontSize,
                                color: Colors.white70,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),

                        // Zone name + battery
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getTrainingZoneName(device.currentHeartRate),
                              style: TextStyle(
                                fontSize: labelFontSize,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (device.batteryLevel != null)
                              Text(
                                '🔋${device.batteryLevel}%',
                                style: TextStyle(
                                    fontSize: labelFontSize,
                                    color: Colors.white70),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
