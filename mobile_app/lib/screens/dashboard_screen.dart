import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/ble_service.dart';
import '../services/database_service.dart';
import '../services/hrv_service.dart';
import '../services/supabase_repository.dart';
import '../models/training_session.dart';
import '../models/hr_device.dart';
import '../models/person.dart';
import '../utils/timezone_utils.dart';
import 'athlete_detail_screen.dart';
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

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final Map<String, TrainingSession> _activeSessions = {};
  bool _isRecording = false;
  Timer? _recordTimer;
  bool _isSyncing = false;
  bool _bleEnabled = true;
  Timer? _bleCheckTimer;

  final Map<String, List<HeartRateDataPoint>> _heartRateHistoryByDevice = {};
  final Map<String, DateTime> _lastAlertTime = {};
  // seconds spent in each zone index 0-4 per device
  final Map<String, List<int>> _zoneSecondsByDevice = {};
  // timestamped lap/drill markers during a session
  final List<({DateTime time, String label})> _sessionMarkers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final bleService = Provider.of<BLEService>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await bleService.autoReconnectToSavedDevices();

        await _checkBluetoothStatus();
        final updatedBleService =
            Provider.of<BLEService>(context, listen: false);
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

  Future<void> _requestBlePermission(
      BuildContext ctx, BLEService bleService) async {
    // Step 1: check current status before requesting
    final preScan = await Permission.bluetoothScan.status;
    final preConnect = await Permission.bluetoothConnect.status;
    final alreadyPermanentlyDenied =
        preScan.isPermanentlyDenied || preConnect.isPermanentlyDenied;

    if (alreadyPermanentlyDenied) {
      // Skip the doomed request — go straight to settings dialog
      if (!ctx.mounted) return;
      _showPermissionSettingsDialog(ctx);
      return;
    }

    // Step 2: trigger system permission dialog
    final granted = await bleService.requestPermissions();
    if (granted || !ctx.mounted) return;

    // Step 3: denied — check if now permanently denied or just denied once
    final postScan = await Permission.bluetoothScan.status;
    final postConnect = await Permission.bluetoothConnect.status;
    final permanentlyDenied =
        postScan.isPermanentlyDenied || postConnect.isPermanentlyDenied;

    if (!ctx.mounted) return;
    if (permanentlyDenied) {
      _showPermissionSettingsDialog(ctx);
    } else {
      // Denied once — show rationale and offer to try again
      showDialog(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Bluetooth Required'),
          content: const Text(
            'This app needs Bluetooth to connect to heart rate sensors worn by athletes.\n\n'
            'Without it, no sensors can be detected or monitored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Not Now'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await bleService.requestPermissions();
              },
              child: const Text('Allow'),
            ),
          ],
        ),
      );
    }
  }

  void _showPermissionSettingsDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Bluetooth Access Blocked'),
        content: const Text(
          'Bluetooth permission was permanently denied. To fix this:\n\n'
          '1. Tap "Open Settings"\n'
          '2. Go to Permissions → Nearby devices\n'
          '3. Set Bluetooth permissions to "Allow"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
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
      final bleService = Provider.of<BLEService>(context, listen: false);

      HrvService.instance.clearSessionData();

      final timestamp = TimezoneUtils.formatDateTime(DateTime.now());
      int created = 0;

      for (final device in bleService.connectedDevices) {
        if (!device.isConnected || device.currentHeartRate == null) {
          continue;
        }

        final athlete = dbService.getAthleteForSensor(device.id);
        if (athlete == null || _activeSessions.containsKey(athlete.id)) {
          continue;
        }

        final session = await dbService.createSession(
          title: 'Training Session $timestamp',
          trainingType: 'general',
          personId: athlete.id,
        );
        _activeSessions[athlete.id] = session;
        created++;
        debugPrint('Session created: ${session.id} for ${athlete.name}');
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
        _zoneSecondsByDevice.clear();
        _sessionMarkers.clear();
      });
      debugPrint('State updated, activeSessions=${_activeSessions.length}');

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        final bleService = Provider.of<BLEService>(context, listen: false);

        for (final device in bleService.connectedDevices) {
          if (!device.isConnected || device.currentHeartRate == null) {
            continue;
          }

          final athlete = dbService.getAthleteForSensor(device.id);
          if (athlete == null) {
            continue;
          }

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
                  'Late-join session created: ${session.id} for ${athlete.name}');
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
          final history = _heartRateHistoryByDevice[device.id]!;
          history.add(HeartRateDataPoint(
            timestamp: now,
            value: device.currentHeartRate!.toDouble(),
          ));
          if (history.length > 60) history.removeAt(0);

          _zoneSecondsByDevice.putIfAbsent(device.id, () => [0, 0, 0, 0, 0]);
          final zoneIdx = _getZoneIndex(device.currentHeartRate!);
          _zoneSecondsByDevice[device.id]![zoneIdx]++;

          _checkAlerts(device);
        }

        if (mounted) {
          setState(() {});
        }
      });
      debugPrint('Timer started; activeSessions=${_activeSessions.length}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Recording $created athlete${created == 1 ? '' : 's'}'),
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
      setState(() {
        _isRecording = false;
      });
      return;
    }

    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final bleService = Provider.of<BLEService>(context, listen: false);
    final sessionsSnapshot = _activeSessions.values.toList(growable: false);
    final athleteCount = sessionsSnapshot.length;

    for (final session in sessionsSnapshot) {
      await dbService.endSession(session.id);
    }

    for (final device in bleService.connectedDevices) {
      final athlete = dbService.getAthleteForSensor(device.id);
      if (athlete != null) {
        await HrvService.instance.saveSessionHrv(
          athlete.id,
          device.id,
          device.currentHeartRate,
        );
      }
    }
    HrvService.instance.clearSessionData();

    setState(() {
      _isRecording = false;
      _activeSessions.clear();
      _heartRateHistoryByDevice.clear();
      _zoneSecondsByDevice.clear();
      _sessionMarkers.clear();
    });

    _syncSessionsToCloud(sessionsSnapshot);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Saved $athleteCount session${athleteCount == 1 ? '' : 's'} and syncing to cloud...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _syncSessionsToCloud(List<TrainingSession> sessions) async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final supabaseRepository = SupabaseRepository();

      int successCount = 0;
      for (final session in sessions) {
        final success =
            await dbService.syncSessionToCloud(session, supabaseRepository);
        if (success) {
          successCount++;
        }
      }

      if (mounted) {
        if (successCount == sessions.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Synced $successCount session${successCount == 1 ? '' : 's'} to cloud successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Saved ${sessions.length} locally; $successCount synced, others will retry later'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
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
        toolbarHeight: 36,
        leading: Consumer<BLEService>(
          builder: (context, bleService, _) {
            final count =
                bleService.connectedDevices.where((d) => d.isConnected).length;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.orange.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bluetooth permissions required.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _requestBlePermission(context, bleService),
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
                  Icon(Icons.warning_amber,
                      color: Colors.red.shade700, size: 20),
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
                    final isLandscape =
                        constraints.maxWidth > constraints.maxHeight;
                    final cols = isLandscape ? 5 : 4;
                    final rows = isLandscape ? 4 : 5;
                    final totalSlots = cols * rows;

                    return GridView.builder(
                      padding: const EdgeInsets.all(outerPad),
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                        childAspectRatio: 1.0, // square cards
                      ),
                      itemCount: totalSlots,
                      itemBuilder: (context, index) {
                        if (index < connected.length) {
                          final device = connected[index];
                          final athlete = DatabaseService.instance
                              .getAthleteForSensor(device.id);
                          return _buildSquareDeviceCard(
                              device, index + 1, athlete);
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

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRecording) ...[
                FloatingActionButton(
                  heroTag: 'dashboard_fab_lap',
                  onPressed: _markLap,
                  backgroundColor: Colors.blueGrey,
                  mini: true,
                  child: const Icon(Icons.flag, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              FloatingActionButton.extended(
                heroTag: 'dashboard_fab',
                onPressed: onPressed,
                icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
                label: Text(_isRecording
                    ? 'Stop Training (${_activeSessions.length})'
                    : 'Start Training'),
                backgroundColor: _isRecording ? Colors.red : Colors.green,
              ),
            ],
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

  Widget _buildSquareDeviceCard(
      HRDevice device, int memberNumber, Person? athlete) {
    final zoneColor = _getHeartRateColorByTrainingZone(device.currentHeartRate);

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          if (_isRecording) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AthleteDetailScreen(
                  device: device,
                  athlete: athlete,
                  hrHistory: List.unmodifiable(
                      _heartRateHistoryByDevice[device.id] ?? []),
                  zoneSecs: _zoneSecondsByDevice[device.id] != null
                      ? List.unmodifiable(_zoneSecondsByDevice[device.id]!)
                      : null,
                ),
              ),
            );
          } else if (athlete != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReadinessScreen(initialAthlete: athlete),
              ),
            );
          } else {
            _showSensorAssignmentDialog(context, device, athlete);
          }
        },
        onLongPress: _isRecording
            ? null
            : () => _showSensorAssignmentDialog(context, device, athlete),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final w = constraints.maxWidth;
            // Scale fonts relative to card size
            final nameFontSize = (h * 0.09).clamp(8.0, 16.0);
            final bpmFontSize = (h * 0.38).clamp(24.0, 80.0);
            final labelFontSize = (h * 0.07).clamp(7.0, 14.0);

            final avatarRadius = (h * 0.22).clamp(16.0, 36.0);
            // Text color: dark for bright zones (yellow), white for dark zones
            final isDarkText = zoneColor == const Color(0xFFFDD835);
            final textColor = isDarkText ? Colors.black87 : Colors.white;
            final subTextColor = isDarkText ? Colors.black54 : Colors.white70;

            final sparklineHistory = _heartRateHistoryByDevice[device.id] ?? [];
            final zoneSecs = _zoneSecondsByDevice[device.id];
            final hrvColor = _hrvTrafficLight(device);
            final signalBars = _rssiToBars(device.rssi);
            final stripH = h * 0.28;
            final sparklineH = h * 0.18;
            final zoneBarsH = h * 0.10;

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: zoneColor,
              ),
              child: Stack(
                children: [
                  // Card content
                  Padding(
                    padding: EdgeInsets.fromLTRB(w * 0.06, h * 0.07, w * 0.06,
                        stripH + sparklineH + zoneBarsH),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // LEFT: athlete photo
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.favorite,
                              color: subTextColor, size: avatarRadius * 0.9),
                        ),
                        SizedBox(width: w * 0.06),
                        // RIGHT: name + BPM
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                athlete?.name ?? '—',
                                style: TextStyle(
                                  fontSize: nameFontSize,
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  device.currentHeartRate?.toString() ?? '--',
                                  style: TextStyle(
                                    fontSize: bpmFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              Text(
                                'bpm',
                                style: TextStyle(
                                  fontSize: labelFontSize,
                                  color: subTextColor,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // HRV traffic light dot — top-right corner
                  if (hrvColor != null)
                    Positioned(
                      top: h * 0.06,
                      right: w * 0.06,
                      child: Container(
                        width: (h * 0.08).clamp(6.0, 12.0),
                        height: (h * 0.08).clamp(6.0, 12.0),
                        decoration: BoxDecoration(
                          color: hrvColor,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 2)
                          ],
                        ),
                      ),
                    ),

                  // Zone bars — sits between sparkline and bottom strip
                  if (zoneSecs != null)
                    Positioned(
                      left: w * 0.04,
                      right: w * 0.04,
                      bottom: stripH,
                      height: zoneBarsH,
                      child: _ZoneBars(zoneSecs: zoneSecs, height: zoneBarsH),
                    ),

                  // Sparkline — sits just above the zone bars (or strip if no session)
                  if (sparklineHistory.length >= 2)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: stripH + (zoneSecs != null ? zoneBarsH : 0),
                      height: sparklineH,
                      child: ClipRect(
                        child: CustomPaint(
                          painter: _SparklinePainter(
                            points: sparklineHistory,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),

                  // Bottom strip: zone name + signal + battery + assign button
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: stripH,
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: w * 0.06),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getTrainingZoneName(device.currentHeartRate),
                            style: TextStyle(
                              fontSize: labelFontSize,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              // RSSI signal bars
                              _SignalIcon(
                                  bars: signalBars,
                                  size: (h * 0.11).clamp(8.0, 16.0)),
                              SizedBox(width: w * 0.02),
                              if (device.batteryLevel != null)
                                Text(
                                  '🔋${device.batteryLevel}%',
                                  style: TextStyle(
                                      fontSize: labelFontSize,
                                      color: Colors.white70),
                                ),
                              SizedBox(width: w * 0.02),
                              GestureDetector(
                                onTap: () => _showSensorAssignmentDialog(
                                    context, device, athlete),
                                child: Icon(
                                  athlete == null
                                      ? Icons.person_add
                                      : Icons.swap_horiz,
                                  color: Colors.white70,
                                  size: (h * 0.12).clamp(10.0, 18.0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  /// Gets color based on training zones (more detailed than basic HR color)
  /// Zone 1 (Recovery): < 120 bpm - Light blue
  /// Zone 2 (Aerobic): 120-150 bpm - Green
  /// Zone 3 (Tempo): 150-170 bpm - Yellow/Orange
  /// Zone 4 (Threshold): 170-190 bpm - Orange
  /// Zone 5 (Anaerobic): >= 190 bpm - Red
  // Standard 5-zone colors (Polar/Garmin convention)
  Color _getHeartRateColorByTrainingZone(int? heartRate) {
    if (heartRate == null) return const Color(0xFF757575); // grey — no data
    if (heartRate < 120)
      return const Color(0xFF4FC3F7); // Z1 light blue — Recovery
    if (heartRate < 150) return const Color(0xFF66BB6A); // Z2 green — Aerobic
    if (heartRate < 170) return const Color(0xFFFDD835); // Z3 yellow — Tempo
    if (heartRate < 190)
      return const Color(0xFFFF7043); // Z4 orange — Threshold
    return const Color(0xFFE53935); // Z5 red — Anaerobic
  }

  int _getZoneIndex(int heartRate) {
    if (heartRate < 120) return 0;
    if (heartRate < 150) return 1;
    if (heartRate < 170) return 2;
    if (heartRate < 190) return 3;
    return 4;
  }

  String _getTrainingZoneName(int? heartRate) {
    if (heartRate == null) return 'Rest';
    if (heartRate < 120) return 'Recovery';
    if (heartRate < 150) return 'Aerobic';
    if (heartRate < 170) return 'Tempo';
    if (heartRate < 190) return 'Threshold';
    return 'Anaerobic';
  }

  void _markLap() {
    final lapNum =
        _sessionMarkers.where((m) => m.label.startsWith('Lap')).length + 1;
    final marker = (time: DateTime.now(), label: 'Lap $lapNum');
    setState(() => _sessionMarkers.add(marker));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Lap $lapNum marked'),
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.blueGrey,
    ));
  }

  void _checkAlerts(HRDevice device) {
    final now = DateTime.now();
    final last = _lastAlertTime[device.id];
    if (last != null && now.difference(last).inSeconds < 60) return;

    String? message;
    if (device.currentHeartRate != null && device.currentHeartRate! >= 190) {
      final athlete = DatabaseService.instance.getAthleteForSensor(device.id);
      final name = athlete?.name ?? device.name;
      message = '⚠️ $name HR ${device.currentHeartRate} bpm — Anaerobic zone!';
    } else if (device.batteryLevel != null && device.batteryLevel! <= 10) {
      final athlete = DatabaseService.instance.getAthleteForSensor(device.id);
      final name = athlete?.name ?? device.name;
      message = '🔋 $name sensor battery low (${device.batteryLevel}%)';
    }

    if (message != null && mounted) {
      _lastAlertTime[device.id] = now;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.deepOrange,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  // RMSSD from the device's current RR interval list (ms). Returns null if < 2 intervals.
  double? _computeRmssd(List<int>? rrIntervals) {
    if (rrIntervals == null || rrIntervals.length < 2) return null;
    double sumSq = 0;
    for (int i = 1; i < rrIntervals.length; i++) {
      final diff = (rrIntervals[i] - rrIntervals[i - 1]).toDouble();
      sumSq += diff * diff;
    }
    return math.sqrt(sumSq / (rrIntervals.length - 1));
  }

  // Green ≥40ms, Yellow ≥20ms, Red <20ms, null = no data
  Color? _hrvTrafficLight(HRDevice device) {
    final rmssd = _computeRmssd(device.rrIntervals);
    if (rmssd == null) return null;
    if (rmssd >= 40) return Colors.greenAccent;
    if (rmssd >= 20) return Colors.yellowAccent;
    return Colors.redAccent;
  }

  // Maps RSSI dBm to 1–4 signal bars
  int _rssiToBars(int rssi) {
    if (rssi >= -60) return 4;
    if (rssi >= -75) return 3;
    if (rssi >= -90) return 2;
    return 1;
  }

  void _showSensorAssignmentDialog(
      BuildContext context, HRDevice device, Person? currentAthlete) {
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
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
              child:
                  const Text('Unassign', style: TextStyle(color: Colors.red)),
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
                  ? const Icon(Icons.check_circle,
                      color: Colors.green, size: 20)
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

class _ZoneBars extends StatelessWidget {
  final List<int> zoneSecs; // 5 elements, index 0-4
  final double height;

  static const _zoneColors = [
    Color(0xFF4FC3F7), // Z1 light blue
    Color(0xFF66BB6A), // Z2 green
    Color(0xFFFDD835), // Z3 yellow
    Color(0xFFFF7043), // Z4 orange
    Color(0xFFE53935), // Z5 red
  ];

  const _ZoneBars({required this.zoneSecs, required this.height});

  @override
  Widget build(BuildContext context) {
    final total = zoneSecs.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    return Row(
      children: List.generate(5, (i) {
        final flex = zoneSecs[i];
        if (flex == 0) return const SizedBox.shrink();
        return Expanded(
          flex: flex,
          child: Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: _zoneColors[i].withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<HeartRateDataPoint> points;
  final Color color;

  _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minVal = points.map((p) => p.value).reduce(math.min);
    final maxVal = points.map((p) => p.value).reduce(math.max);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i / (points.length - 1) * size.width;
      final y = size.height -
          ((points[i].value - minVal) / range) * size.height * 0.9 -
          size.height * 0.05;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.points != points;
}

class _SignalIcon extends StatelessWidget {
  final int bars; // 1–4
  final double size;

  const _SignalIcon({required this.bars, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (i) {
          final active = i < bars;
          return Container(
            width: size * 0.18,
            height: size * (0.25 + i * 0.25),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white30,
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
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
                                  final device =
                                      bleService.discoveredDevices[index];
                                  final isConnected = device.isConnected;
                                  final isConnecting =
                                      _connectingDevices.contains(device.id);

                                  return ListTile(
                                    leading: const Icon(Icons.bluetooth),
                                    title: Text(device.name),
                                    subtitle:
                                        Text('Signal: ${device.rssi} dBm'),
                                    trailing: isConnected
                                        ? const Icon(Icons.check,
                                            color: Colors.green)
                                        : bleService.connectedDevices.length >=
                                                10
                                            ? const Tooltip(
                                                message:
                                                    'Max devices connected',
                                                child: Icon(Icons.lock,
                                                    color: Colors.grey),
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: isConnecting
                                                        ? null
                                                        : () async {
                                                            setState(() {
                                                              _connectingDevices
                                                                  .add(device
                                                                      .id);
                                                            });

                                                            try {
                                                              final success =
                                                                  await bleService
                                                                      .connectDevice(
                                                                          device);
                                                              if (mounted) {
                                                                if (success) {
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    SnackBar(
                                                                        content:
                                                                            Text('Connected to ${device.name}')),
                                                                  );
                                                                } else {
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(
                                                                          'Failed to connect to ${device.name}'),
                                                                      backgroundColor:
                                                                          Colors
                                                                              .red,
                                                                    ),
                                                                  );
                                                                }
                                                              }
                                                            } finally {
                                                              setState(() {
                                                                _connectingDevices
                                                                    .remove(
                                                                        device
                                                                            .id);
                                                              });
                                                            }
                                                          },
                                                    child: isConnecting
                                                        ? const SizedBox(
                                                            height: 16,
                                                            width: 16,
                                                            child:
                                                                CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2),
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
                        future: Provider.of<BLEService>(context, listen: false)
                            .getSavedConnectedDevices(),
                        builder: (context, snap) {
                          if (!snap.hasData || snap.data!.isEmpty)
                            return const SizedBox.shrink();

                          // Filter out devices that are already discovered or connected
                          final savedDevices = snap.data!
                              .where((sd) =>
                                  !bleService.discoveredDevices
                                      .any((d) => d.id == sd.id) &&
                                  !bleService.connectedDevices
                                      .any((d) => d.id == sd.id))
                              .toList();

                          if (savedDevices.isEmpty)
                            return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Saved Devices',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: (savedDevices.length * 56)
                                    .toDouble()
                                    .clamp(0, 200),
                                child: ListView.builder(
                                  itemCount: savedDevices.length,
                                  itemBuilder: (context, i) {
                                    final sd = savedDevices[i];
                                    final isConnecting =
                                        _connectingDevices.contains(sd.id);
                                    return ListTile(
                                      leading: const Icon(Icons.history,
                                          color: Colors.grey),
                                      title: Text(sd.name,
                                          style: const TextStyle(fontSize: 12)),
                                      subtitle: Text(sd.id,
                                          style: const TextStyle(fontSize: 10)),
                                      trailing: ElevatedButton(
                                        onPressed: isConnecting
                                            ? null
                                            : () async {
                                                setState(() {
                                                  _connectingDevices.add(sd.id);
                                                });
                                                try {
                                                  final success = await Provider
                                                          .of<BLEService>(
                                                              context,
                                                              listen: false)
                                                      .connectDevice(sd);
                                                  if (mounted) {
                                                    if (success) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(SnackBar(
                                                              content: Text(
                                                                  'Restored ${sd.name}')));
                                                    } else {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(SnackBar(
                                                              content: Text(
                                                                  'Failed to restore ${sd.name}'),
                                                              backgroundColor:
                                                                  Colors.red));
                                                    }
                                                  }
                                                } finally {
                                                  setState(() {
                                                    _connectingDevices
                                                        .remove(sd.id);
                                                  });
                                                }
                                              },
                                        child: isConnecting
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))
                                            : const Text('Restore',
                                                style: TextStyle(fontSize: 11)),
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
