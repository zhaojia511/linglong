import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';
import '../services/database_service.dart';
import '../services/supabase_repository.dart';
import '../models/training_session.dart';
import '../models/hr_device.dart';
import '../models/core_temp_device.dart';
import '../models/person.dart';
import '../services/core_temp_service.dart';
import '../services/hrv_service.dart';
import 'team_readiness_screen.dart';
import 'readiness_screen.dart';

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
  // Active sessions keyed by athleteId — one session per worn, paired sensor.
  final Map<String, TrainingSession> _activeSessions = {};
  bool _isRecording = false;
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
        // Restore previously connected devices (HR + CoreTemp)
        await bleService.autoReconnectToSavedDevices();
        final coreTempService =
            Provider.of<CoreTempService>(context, listen: false);
        await coreTempService.autoReconnect();

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
      final bleService = Provider.of<BLEService>(context, listen: false);

      HrvService.instance.clearSessionData();

      // Create one session per worn, paired device. Sensors that are paired
      // but not producing HR (i.e. not currently worn) are skipped — they'll
      // be picked up mid-session by the timer below if HR appears.
      final timestamp = DateTime.now().toString().substring(0, 16);
      int created = 0;
      for (final device in bleService.connectedDevices) {
        if (device.currentHeartRate == null) continue;
        final athlete =
            DatabaseService.instance.getAthleteForSensor(device.id);
        if (athlete == null) continue;
        if (_activeSessions.containsKey(athlete.id)) continue;

        final session = await dbService.createSession(
          title: 'Training Session $timestamp',
          trainingType: 'general',
          personId: athlete.id,
        );
        _activeSessions[athlete.id] = session;
        created++;
        debugPrint('Session ${session.id} created for ${athlete.name}');
      }

      if (created == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No worn paired sensors detected. Put on chest straps and try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      setState(() {
        _isRecording = true;
        _heartRateHistoryByDevice.clear();
      });

      // Record heart rate every second.
      // Mid-session: if a paired sensor starts producing HR (athlete puts strap
      // on late, or strap reconnects), spin up a session for that athlete.
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        final bleService = Provider.of<BLEService>(context, listen: false);

        for (final device in bleService.connectedDevices) {
          if (device.currentHeartRate == null) continue;

          final athlete =
              DatabaseService.instance.getAthleteForSensor(device.id);
          if (athlete == null) continue;

          // Lazily create a session for any newly-worn paired sensor.
          var session = _activeSessions[athlete.id];
          if (session == null) {
            try {
              session = await dbService.createSession(
                title: 'Training Session $timestamp',
                trainingType: 'general',
                personId: athlete.id,
              );
              _activeSessions[athlete.id] = session;
              debugPrint(
                  'Late-join session ${session.id} created for ${athlete.name}');
            } catch (e) {
              debugPrint('Failed to create late-join session: $e');
              continue;
            }
          }

          final now = DateTime.now();
          session.heartRateData.add(HeartRateData(
            timestamp: now,
            heartRate: device.currentHeartRate!,
            deviceId: device.id,
          ));

          if (device.rrIntervals != null && device.rrIntervals!.isNotEmpty) {
            HrvService.instance.addRRIntervals(device.id, device.rrIntervals!);
          }

          _heartRateHistoryByDevice.putIfAbsent(device.id, () => []);
          _heartRateHistoryByDevice[device.id]!.add(
            HeartRateDataPoint(
              timestamp: now,
              value: device.currentHeartRate!.toDouble(),
            ),
          );
        }
        if (mounted) setState(() {});
      });
      debugPrint('Timer started; $created session(s) active');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording $created athlete${created == 1 ? "" : "s"}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
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
    _recordTimer = null;

    if (_activeSessions.isEmpty) {
      setState(() => _isRecording = false);
      return;
    }

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final bleService = Provider.of<BLEService>(context, listen: false);

    final sessionsSnapshot = _activeSessions.values.toList(growable: false);
    final athleteCount = sessionsSnapshot.length;

    // Finalize each session (computes stats, persists endTime).
    for (final session in sessionsSnapshot) {
      await dbService.endSession(session.id);
    }

    // Save HRV snapshot for each assigned athlete with a worn strap.
    for (final device in bleService.connectedDevices) {
      final athlete = DatabaseService.instance.getAthleteForSensor(device.id);
      if (athlete != null) {
        await HrvService.instance.saveSessionHrv(
          athlete.id,
          device.id,
          device.currentHeartRate,
        );
      }
    }
    HrvService.instance.clearSessionData();

    // Kick off cloud sync per session in background.
    for (final session in sessionsSnapshot) {
      // Re-fetch the persisted session so endTime/stats are present.
      final stored = dbService.getAllSessions().firstWhere(
            (s) => s.id == session.id,
            orElse: () => session,
          );
      _syncSessionToCloud(stored);
    }

    setState(() {
      _isRecording = false;
      _activeSessions.clear();
      _heartRateHistoryByDevice.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Saved $athleteCount athlete session${athleteCount == 1 ? "" : "s"}, syncing to cloud...'),
          duration: const Duration(seconds: 2),
        ),
      );
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
        toolbarHeight: 48,
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
                          Platform.isAndroid
                              ? 'Bluetooth permissions required.'
                              : 'Bluetooth permissions required. Enable in Settings > Privacy & Security > Bluetooth.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          if (Platform.isAndroid) {
                            final granted = await bleService.requestPermissions();
                            if (!granted && mounted) {
                              // Permanently denied — open app settings
                              await openAppSettings();
                            }
                          } else {
                            await openAppSettings();
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
          // Team readiness banner
          _TeamReadinessBanner(),
          // Main content — full-screen grid
          Expanded(
            child: Consumer2<BLEService, CoreTempService>(
              builder: (context, bleService, coreTempService, child) {
                final hrDevices = bleService.connectedDevices
                    .where((d) => d.isConnected)
                    .toList();
                final tempDevices = coreTempService.connectedDevices
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

                    // Card size = whichever axis is the limiting one, keeping square
                    final availW = constraints.maxWidth - outerPad * 2 - (cols - 1) * gap;
                    final availH = constraints.maxHeight - outerPad * 2 - (rows - 1) * gap;
                    final cellSize = (availW / cols).clamp(0.0, availH / rows);
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
                        if (index < hrDevices.length) {
                          final device = hrDevices[index];
                          final athlete = DatabaseService.instance
                              .getAthleteForSensor(device.id);
                          return _buildSquareDeviceCard(device, index + 1, athlete);
                        }
                        final tempIndex = index - hrDevices.length;
                        if (tempIndex < tempDevices.length) {
                          final device = tempDevices[tempIndex];
                          final athlete = DatabaseService.instance
                              .getAthleteForSensor(device.id);
                          return _buildCoreTempCard(device, index + 1, athlete);
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
          final connectedDevices =
              bleService.connectedDevices.where((d) => d.isConnected).toList();
          debugPrint(
              'FAB check: recording=$_isRecording, activeSessions=${_activeSessions.length}, connectedCount=${connectedDevices.length}');

          VoidCallback? onPressed;
          if (!_isRecording && connectedDevices.isNotEmpty) {
            onPressed = () {
              debugPrint('Starting recording...');
              _startRecording();
            };
          } else if (_isRecording) {
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
            icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
            label: Text(_isRecording
                ? 'Stop Training (${_activeSessions.length})'
                : 'Start Training'),
            backgroundColor: _isRecording ? Colors.red : Colors.green,
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

  Widget _buildCoreTempCard(CoreTempDevice device, int slotNumber, Person? athlete) {
    final bgColor = _getCoreTempColor(device.coreTemperature);
    final accentColor = _getColorForMember(slotNumber);

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showSensorAssignmentDialogForCoreTemp(context, device, athlete),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final w = constraints.maxWidth;
            final nameFontSize = (h * 0.09).clamp(8.0, 16.0);
            final valueFontSize = (h * 0.30).clamp(20.0, 64.0);
            final labelFontSize = (h * 0.07).clamp(7.0, 14.0);
            final iconSize = (h * 0.14).clamp(12.0, 28.0);

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: bgColor,
              ),
              child: Stack(
                children: [
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
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: w * 0.05, vertical: h * 0.05),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          athlete?.name ?? 'Tap to assign',
                          style: TextStyle(
                            fontSize: nameFontSize,
                            color: athlete != null ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sensors,
                                color: Colors.white70, size: iconSize),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                device.coreTemperature != null
                                    ? device.coreTemperature!.toStringAsFixed(1)
                                    : '--',
                                style: TextStyle(
                                  fontSize: valueFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            Text(
                              '°C core',
                              style: TextStyle(
                                fontSize: labelFontSize,
                                color: Colors.white70,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              device.skinTemperature != null
                                  ? 'skin ${device.skinTemperature!.toStringAsFixed(1)}°'
                                  : device.qualityLabel,
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

  Color _getCoreTempColor(double? temp) {
    if (temp == null) return Colors.grey[600]!;
    if (temp < 37.2) return const Color(0xFF1E88E5); // normal — blue
    if (temp < 38.0) return const Color(0xFFFFB300); // elevated — amber
    return const Color(0xFFE53935);                   // high — red
  }

  void _showSensorAssignmentDialogForCoreTemp(
      BuildContext context, CoreTempDevice device, Person? currentAthlete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign CoreTemp Sensor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sensor: ${device.name}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 8),
            if (currentAthlete != null)
              Text('Currently assigned to: ${currentAthlete.name}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            const Text('Assign to:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildAthleteListForDevice(device.id),
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
            onPressed: () async {
              final coreTempService =
                  Provider.of<CoreTempService>(context, listen: false);
              final msg = await coreTempService.clearPairedHRMs(device);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg)),
                );
              }
            },
            child: const Text('Clear HRMs',
                style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildAthleteListForDevice(String deviceId) {
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
            final isAssigned = athlete.hasSensorAssigned(deviceId);
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: _getColorForAthlete(athlete),
                child: Text(athlete.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
              title: Text(athlete.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isAssigned ? FontWeight.bold : FontWeight.normal,
                  )),
              subtitle: Text('${athlete.age}y, ${athlete.gender}',
                  style: const TextStyle(fontSize: 11)),
              trailing: isAssigned
                  ? const Icon(Icons.check_circle,
                      color: Colors.green, size: 20)
                  : null,
              onTap: () async {
                await DatabaseService.instance
                    .assignSensorToAthlete(deviceId, athlete.id);
                if (context.mounted) Navigator.pop(context);
                setState(() {});
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSquareDeviceCard(HRDevice device, int memberNumber, Person? athlete) {
    final zoneColor = _getHeartRateColorByTrainingZone(device.currentHeartRate);
    final accentColor = _getColorForMember(memberNumber);
    final liveRmssd = HrvService.instance.getLiveRmssd(device.id);
    final readiness = athlete != null
        ? HrvService.instance.getReadiness(athlete.id, currentRmssd: liveRmssd)
        : null;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          // Daily action: tap → start readiness measurement for this athlete.
          // If the sensor isn't paired yet, fall back to the assignment dialog.
          if (athlete == null) {
            _showSensorAssignmentDialog(context, device, athlete);
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReadinessScreen(initialAthlete: athlete),
            ),
          );
        },
        // Long-press = setup action: re-assign or unassign the sensor.
        onLongPress: () =>
            _showSensorAssignmentDialog(context, device, athlete),
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
                        // Athlete name / assign prompt (with readiness dot)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (readiness != null) ...[
                              Container(
                                width: (labelFontSize * 0.8).clamp(5.0, 9.0),
                                height: (labelFontSize * 0.8).clamp(5.0, 9.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: readiness.color,
                                ),
                              ),
                              const SizedBox(width: 3),
                            ],
                            Flexible(
                              child: Text(
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
                            ),
                          ],
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

                        // Zone / RMSSD + battery
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                liveRmssd != null
                                    ? 'RMSSD ${liveRmssd.toStringAsFixed(0)}ms'
                                    : _getTrainingZoneName(
                                        device.currentHeartRate),
                                style: TextStyle(
                                  fontSize: labelFontSize,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
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

// ── Team readiness banner ─────────────────────────────────────────────────────

class _TeamReadinessBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final athletes = DatabaseService.instance.getAthletes();
    if (athletes.isEmpty) return const SizedBox.shrink();

    final hrv = HrvService.instance;
    final ids = athletes.map((a) => a.id).toList();
    final teamAvg = hrv.getTeamAvgReadiness(ids);
    if (teamAvg == null) return const SizedBox.shrink(); // no baselines yet

    // Team-level acute / chronic fatigue
    FatigueScore? teamFatigue(int days) {
      final scores = athletes
          .map((a) => hrv.getFatigue(a.id, days: days))
          .whereType<FatigueScore>()
          .toList();
      if (scores.isEmpty) return null;
      final avgR = scores.map((s) => s.windowAvgRmssd).reduce((a, b) => a + b) /
          scores.length;
      final avgB =
          scores.map((s) => s.baseline).reduce((a, b) => a + b) / scores.length;
      final pct = (avgR / avgB * 100).clamp(0.0, 150.0);
      final level = pct >= 90
          ? FatigueLevel.low
          : pct >= 75
              ? FatigueLevel.elevated
              : pct >= 60
                  ? FatigueLevel.high
                  : FatigueLevel.veryHigh;
      return FatigueScore(
          level: level, windowAvgRmssd: avgR, baseline: avgB, days: days);
    }

    final acute = teamFatigue(7);
    final chronic = teamFatigue(28);

    final readiness = ReadinessScore(
      percent: teamAvg,
      baseline: 100,
      currentRmssd: teamAvg,
    );

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TeamReadinessScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          children: [
            // Readiness % pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: readiness.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: readiness.color.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'READINESS',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: readiness.color),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${teamAvg.toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: readiness.color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Fatigue chips
            if (acute != null)
              _FatigueChip('Acute', acute),
            if (acute != null && chronic != null)
              const SizedBox(width: 6),
            if (chronic != null)
              _FatigueChip('Chronic', chronic),
            const Spacer(),
            Icon(Icons.chevron_right,
                size: 16, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}

class _FatigueChip extends StatelessWidget {
  final String label;
  final FatigueScore score;
  const _FatigueChip(this.label, this.score);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(score.label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: score.color)),
      ],
    );
  }
}

// ── Device dialog ─────────────────────────────────────────────────────────────

class DeviceDialog extends StatefulWidget {
  const DeviceDialog({super.key});

  @override
  State<DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<DeviceDialog> {
  final Set<String> _connectingDevices = {};
  bool _bleAvailable = true;
  bool _hasScanned = false;
  int _selectedTab = 0; // 0 = Heart Rate, 1 = Core Temp

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bleService = Provider.of<BLEService>(context, listen: false);
      await _checkBluetoothAvailability();
      await bleService.checkPermissions();
      final error = await bleService.startScan();
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red,
              duration: const Duration(seconds: 3)),
        );
      }
    });
  }

  Future<void> _checkBluetoothAvailability() async {
    final bleService = Provider.of<BLEService>(context, listen: false);
    final available = await bleService.isBluetoothAvailable();
    if (mounted) setState(() => _bleAvailable = available);
  }

  Future<void> _handleRescan() async {
    setState(() => _hasScanned = true);
    if (_selectedTab == 0) {
      final bleService = Provider.of<BLEService>(context, listen: false);
      final error = await bleService.startScan();
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red,
              duration: const Duration(seconds: 3)),
        );
      }
    } else {
      final coreTempService =
          Provider.of<CoreTempService>(context, listen: false);
      final error = await coreTempService.startScan();
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red,
              duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bluetooth Devices'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bluetooth warning
            if (!_bleAvailable)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
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
                        'Bluetooth is not enabled.',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            // Tab selector
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.favorite, size: 16),
                  label: Text('Heart Rate'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.sensors, size: 16),
                  label: Text('Core Temp'),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (s) {
                setState(() {
                  _selectedTab = s.first;
                  _hasScanned = false;
                });
              },
            ),
            const SizedBox(height: 8),
            // Scan row + progress
            if (_selectedTab == 0)
              _buildHRPanel()
            else
              _buildCoreTempPanel(),
          ],
        ),
      ),
      actions: [
        Consumer2<BLEService, CoreTempService>(
          builder: (context, bleService, coreTempService, child) {
            final total = bleService.connectedDevices.length +
                coreTempService.connectedDevices.length;
            return TextButton(
              onPressed: total == 0
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Disconnect All?'),
                          content: Text('Disconnect $total device(s)?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                bleService.disconnectAllDevices();
                                coreTempService.disconnectAll();
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

  Widget _buildHRPanel() {
    return Consumer<BLEService>(
      builder: (context, bleService, _) {
        final connected = bleService.connectedDevices.where((d) => d.isConnected).toList();
        final available = bleService.discoveredDevices
            .where((d) => !connected.any((c) => c.id == d.id))
            .toList();

        return Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Connected section ──────────────────────────────────────
                if (connected.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Connected (${connected.length})',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600])),
                  ),
                  ...connected.map((device) {
                    final isDisconnecting = _connectingDevices.contains('dc:${device.id}');
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(Icons.favorite, color: Colors.green[600], size: 20),
                      title: Text(device.name, style: const TextStyle(fontSize: 13)),
                      subtitle: device.currentHeartRate != null
                          ? Text('${device.currentHeartRate} bpm',
                              style: const TextStyle(fontSize: 11))
                          : null,
                      trailing: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                        ),
                        onPressed: isDisconnecting
                            ? null
                            : () async {
                                setState(() =>
                                    _connectingDevices.add('dc:${device.id}'));
                                try {
                                  await bleService.disconnectDevice(device);
                                } finally {
                                  if (mounted) {
                                    setState(() => _connectingDevices
                                        .remove('dc:${device.id}'));
                                  }
                                }
                              },
                        child: isDisconnecting
                            ? const SizedBox(
                                height: 14, width: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Disconnect',
                                style: TextStyle(fontSize: 12)),
                      ),
                    );
                  }),
                  const Divider(height: 16),
                ],
                // ── Available / scan section ───────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Available',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600])),
                    bleService.isScanning
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton(
                            onPressed: _handleRescan,
                            child: Text(_hasScanned ? 'Rescan' : 'Scan',
                                style: const TextStyle(fontSize: 12))),
                  ],
                ),
                if (bleService.isScanning)
                  const LinearProgressIndicator()
                else
                  const SizedBox(height: 2),
                if (available.isEmpty)
                  _emptyState(bleService.isScanning)
                else
                  ...available.map((device) {
                    final isConnecting = _connectingDevices.contains(device.id);
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.favorite_border, size: 20),
                      title: Text(device.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${device.rssi} dBm',
                          style: const TextStyle(fontSize: 11)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                        ),
                        onPressed: isConnecting
                            ? null
                            : () async {
                                setState(() =>
                                    _connectingDevices.add(device.id));
                                try {
                                  final ok =
                                      await bleService.connectDevice(device);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(ok
                                          ? 'Connected to ${device.name}'
                                          : 'Failed to connect'),
                                      backgroundColor:
                                          ok ? null : Colors.red,
                                    ));
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _connectingDevices
                                        .remove(device.id));
                                  }
                                }
                              },
                        child: isConnecting
                            ? const SizedBox(
                                height: 14, width: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Text('Connect',
                                style: TextStyle(fontSize: 12)),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoreTempPanel() {
    return Consumer<CoreTempService>(
      builder: (context, coreTempService, _) {
        final connected = coreTempService.connectedDevices.where((d) => d.isConnected).toList();
        final available = coreTempService.discoveredDevices
            .where((d) => !connected.any((c) => c.id == d.id))
            .toList();

        return Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Connected section ──────────────────────────────────────
                if (connected.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Connected (${connected.length})',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600])),
                  ),
                  ...connected.map((device) {
                    final isDisconnecting =
                        _connectingDevices.contains('dc:${device.id}');
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(Icons.sensors, color: Colors.green[600], size: 20),
                      title: Text(device.name, style: const TextStyle(fontSize: 13)),
                      subtitle: device.coreTemperature != null
                          ? Text(
                              '${device.coreTemperature!.toStringAsFixed(1)}°C core',
                              style: const TextStyle(fontSize: 11))
                          : null,
                      trailing: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                        ),
                        onPressed: isDisconnecting
                            ? null
                            : () async {
                                setState(() => _connectingDevices
                                    .add('dc:${device.id}'));
                                try {
                                  await coreTempService.disconnectDevice(device);
                                } finally {
                                  if (mounted) {
                                    setState(() => _connectingDevices
                                        .remove('dc:${device.id}'));
                                  }
                                }
                              },
                        child: isDisconnecting
                            ? const SizedBox(
                                height: 14, width: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Disconnect',
                                style: TextStyle(fontSize: 12)),
                      ),
                    );
                  }),
                  const Divider(height: 16),
                ],
                // ── Available / scan section ───────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Available',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600])),
                    coreTempService.isScanning
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton(
                            onPressed: _handleRescan,
                            child: Text(_hasScanned ? 'Rescan' : 'Scan',
                                style: const TextStyle(fontSize: 12))),
                  ],
                ),
                if (coreTempService.isScanning)
                  const LinearProgressIndicator()
                else
                  const SizedBox(height: 2),
                if (available.isEmpty)
                  _emptyState(coreTempService.isScanning)
                else
                  ...available.map((device) {
                    final isConnecting = _connectingDevices.contains(device.id);
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.sensors_off, size: 20),
                      title: Text(device.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${device.rssi} dBm',
                          style: const TextStyle(fontSize: 11)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                        ),
                        onPressed: isConnecting
                            ? null
                            : () async {
                                setState(() =>
                                    _connectingDevices.add(device.id));
                                try {
                                  final ok = await coreTempService
                                      .connectDevice(device);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(ok
                                          ? 'Connected to ${device.name}'
                                          : 'Failed to connect'),
                                      backgroundColor:
                                          ok ? null : Colors.red,
                                    ));
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _connectingDevices
                                        .remove(device.id));
                                  }
                                }
                              },
                        child: isConnecting
                            ? const SizedBox(
                                height: 14, width: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Text('Connect',
                                style: TextStyle(fontSize: 12)),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(bool isScanning) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            isScanning
                ? 'Scanning for devices...'
                : _bleAvailable
                    ? 'No devices found. Tap Scan to search.'
                    : 'Bluetooth is disabled',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
