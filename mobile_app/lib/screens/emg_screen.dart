import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/emg_service.dart';

class EmgScreen extends StatefulWidget {
  const EmgScreen({Key? key}) : super(key: key);

  @override
  State<EmgScreen> createState() => _EmgScreenState();
}

class _EmgScreenState extends State<EmgScreen> {
  final EmgService _emgService = EmgService();
  final List<int> _emgDataPoints = [];
  final int _maxDataPoints = 5000;

  bool _isConnected = false;
  bool _isStreaming = false;
  bool _isScanning = false;
  String _statusMessage = 'No device connected';

  String? _deviceVersion;
  String? _deviceDirection;
  int? _deviceThreshold;

  StreamSubscription? _dataSubscription;
  StreamSubscription? _infoSubscription;
  Timer? _chartUpdateTimer;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _infoSubscription = _emgService.deviceInfoStream.listen((info) {
      setState(() {
        _deviceVersion = info['version'];
        _deviceDirection = info['direction'];
        _deviceThreshold = info['threshold'];
        _statusMessage =
            'Device ready: Version $_deviceVersion, Direction $_deviceDirection';
      });
    });
  }

  Future<void> _scanAndConnect() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for EMG devices...';
    });

    try {
      BluetoothDevice? device = await _emgService.scanForEmgDevice();

      if (device == null) {
        setState(() {
          _statusMessage = 'No EMG device found';
          _isScanning = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Connecting to ${device.name}...';
      });

      bool connected = await _emgService.connect(device);

      if (connected) {
        setState(() {
          _isConnected = true;
          _statusMessage = 'Connected to ${device.name}';
        });

        // Request device info
        await _emgService.requestDeviceInfo();
      } else {
        setState(() {
          _statusMessage = 'Failed to connect';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _disconnect() async {
    await _stopDataStream();
    await _emgService.disconnect();
    setState(() {
      _isConnected = false;
      _statusMessage = 'Disconnected';
      _deviceVersion = null;
      _deviceDirection = null;
      _deviceThreshold = null;
    });
  }

  Future<void> _startDataStream() async {
    if (!_isConnected || _deviceThreshold == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please connect and get device info first')),
      );
      return;
    }

    try {
      _emgDataPoints.clear();
      await _emgService.startDataStream();

      _dataSubscription = _emgService.emgDataStream.listen((values) {
        setState(() {
          _emgDataPoints.addAll(values);
          // Keep only the last maxDataPoints
          if (_emgDataPoints.length > _maxDataPoints) {
            _emgDataPoints.removeRange(
                0, _emgDataPoints.length - _maxDataPoints);
          }
        });
      });

      // Start chart update timer (20ms = 50Hz refresh rate)
      _chartUpdateTimer =
          Timer.periodic(const Duration(milliseconds: 20), (timer) {
        setState(() {}); // Trigger chart redraw
      });

      setState(() {
        _isStreaming = true;
        _statusMessage = 'Streaming EMG data...';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error starting stream: $e';
      });
    }
  }

  Future<void> _stopDataStream() async {
    await _emgService.stopDataStream();
    await _dataSubscription?.cancel();
    _dataSubscription = null;
    _chartUpdateTimer?.cancel();
    _chartUpdateTimer = null;

    setState(() {
      _isStreaming = false;
      _statusMessage = 'Stopped streaming';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMG Monitor'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Status and Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status message
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Device info
                if (_deviceVersion != null)
                  Text(
                    'Version: $_deviceVersion | Direction: $_deviceDirection | Threshold: $_deviceThreshold',
                    style: TextStyle(color: Colors.grey[700]),
                  ),

                const SizedBox(height: 16),

                // Control buttons
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isScanning
                          ? null
                          : (_isConnected ? _disconnect : _scanAndConnect),
                      icon: Icon(_isConnected
                          ? Icons.bluetooth_disabled
                          : Icons.bluetooth_searching),
                      label: Text(_isConnected ? 'Disconnect' : 'Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isConnected ? Colors.red : Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: (_isConnected && !_isStreaming)
                          ? _startDataStream
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isStreaming ? _stopDataStream : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chart
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _buildChart(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_emgDataPoints.isEmpty) {
      return const Center(
        child: Text(
          'No data available. Start streaming to view EMG signal.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Prepare data for chart
    List<FlSpot> spots = [];
    int startIndex = _emgDataPoints.length > _maxDataPoints
        ? _emgDataPoints.length - _maxDataPoints
        : 0;

    for (int i = 0; i < _emgDataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), _emgDataPoints[i].toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Colors.blue,
            barWidth: 1.5,
            dotData: FlDotData(show: false),
          ),
        ],
        minX: 0,
        maxX: _maxDataPoints.toDouble(),
        lineTouchData: LineTouchData(enabled: false),
      ),
    );
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _infoSubscription?.cancel();
    _chartUpdateTimer?.cancel();
    _emgService.dispose();
    super.dispose();
  }
}
