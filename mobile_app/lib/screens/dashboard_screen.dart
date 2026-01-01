import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../services/ble_service.dart';
import '../services/database_service.dart';
import '../models/training_session.dart';
import '../models/hr_device.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  TrainingSession? _activeSession;
  Timer? _recordTimer;
  final List<FlSpot> _heartRateHistory = [];

  @override
  void dispose() {
    _recordTimer?.cancel();
    super.dispose();
  }

  void _startRecording() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    
    final session = await dbService.createSession(
      title: 'Training Session ${DateTime.now().toString().substring(0, 16)}',
      trainingType: 'general',
    );
    
    setState(() {
      _activeSession = session;
      _heartRateHistory.clear();
    });

    // Record heart rate every second
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final bleService = Provider.of<BLEService>(context, listen: false);
      final avgHR = bleService.getAverageHeartRate();
      
      if (avgHR != null && _activeSession != null) {
        final hrData = HeartRateData(
          timestamp: DateTime.now(),
          heartRate: avgHR,
          deviceId: bleService.connectedDevices.first.id,
        );
        
        _activeSession!.heartRateData.add(hrData);
        
        setState(() {
          _heartRateHistory.add(
            FlSpot(
              _activeSession!.heartRateData.length.toDouble(),
              avgHR.toDouble(),
            ),
          );
        });
      }
    });
  }

  void _stopRecording() async {
    _recordTimer?.cancel();
    
    if (_activeSession != null) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.endSession(_activeSession!.id);
      
      setState(() {
        _activeSession = null;
        _heartRateHistory.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Training session saved')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: () => _showDeviceDialog(context),
          ),
        ],
      ),
      body: Consumer<BLEService>(
        builder: (context, bleService, child) {
          final connectedDevices = bleService.connectedDevices;
          final avgHR = bleService.getAverageHeartRate();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Heart Rate Display
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Current Heart Rate',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          avgHR?.toString() ?? '--',
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const Text(
                          'bpm',
                          style: TextStyle(fontSize: 24, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Connected Devices
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connected Devices',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (connectedDevices.isEmpty)
                          const Text('No devices connected')
                        else
                          ...connectedDevices.map((device) => ListTile(
                            leading: const Icon(Icons.favorite, color: Colors.red),
                            title: Text(device.name),
                            subtitle: Text('HR: ${device.currentHeartRate ?? '--'} bpm'),
                            trailing: device.batteryLevel != null
                                ? Text('${device.batteryLevel}%')
                                : null,
                          )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Heart Rate Chart
                if (_activeSession != null && _heartRateHistory.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Heart Rate Trend',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: true),
                                titlesData: const FlTitlesData(show: true),
                                borderData: FlBorderData(show: true),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _heartRateHistory.length > 60
                                        ? _heartRateHistory.sublist(_heartRateHistory.length - 60)
                                        : _heartRateHistory,
                                    isCurved: true,
                                    color: Colors.red,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Recording Controls
                ElevatedButton.icon(
                  onPressed: _activeSession == null && connectedDevices.isNotEmpty
                      ? _startRecording
                      : _activeSession != null
                          ? _stopRecording
                          : null,
                  icon: Icon(_activeSession == null ? Icons.play_arrow : Icons.stop),
                  label: Text(_activeSession == null ? 'Start Training' : 'Stop Training'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: _activeSession == null ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BLEService>(context, listen: false).startScan();
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
                if (bleService.isScanning)
                  const LinearProgressIndicator()
                else
                  TextButton(
                    onPressed: () => bleService.startScan(),
                    child: const Text('Scan for Devices'),
                  ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: bleService.discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = bleService.discoveredDevices[index];
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(device.name),
                        subtitle: Text('Signal: ${device.rssi} dBm'),
                        trailing: device.isConnected
                            ? const Icon(Icons.check, color: Colors.green)
                            : ElevatedButton(
                                onPressed: () async {
                                  final success = await bleService.connectDevice(device);
                                  if (success && mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                child: const Text('Connect'),
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
