import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/hr_device.dart';

class BLEService extends ChangeNotifier {
  final List<HRDevice> _discoveredDevices = [];
  final List<HRDevice> _connectedDevices = [];
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;
  
  // Heart Rate Service UUID (Standard Bluetooth SIG)
  static const String hrServiceUuid = "0000180d-0000-1000-8000-00805f9b34fb";
  static const String hrMeasurementUuid = "00002a37-0000-1000-8000-00805f9b34fb";
  static const String batteryServiceUuid = "0000180f-0000-1000-8000-00805f9b34fb";
  static const String batteryLevelUuid = "00002a19-0000-1000-8000-00805f9b34fb";

  List<HRDevice> get discoveredDevices => _discoveredDevices;
  List<HRDevice> get connectedDevices => _connectedDevices;
  bool get isScanning => _isScanning;

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('Bluetooth permissions not granted');
      return;
    }

    _discoveredDevices.clear();
    _isScanning = true;
    notifyListeners();

    try {
      // Check if Bluetooth is available
      if (await FlutterBluePlus.isAvailable == false) {
        debugPrint("Bluetooth not available");
        return;
      }

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [Guid(hrServiceUuid)], // Only scan for HR devices
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final device = result.device;
          
          // Check if device already discovered
          if (!_discoveredDevices.any((d) => d.id == device.id.toString())) {
            _discoveredDevices.add(HRDevice(
              id: device.id.toString(),
              name: device.name.isNotEmpty ? device.name : 'Unknown Device',
              address: device.id.toString(),
              rssi: result.rssi,
            ));
            notifyListeners();
          }
        }
      });

      // Auto stop scanning after timeout
      await Future.delayed(const Duration(seconds: 15));
      await stopScan();
    } catch (e) {
      debugPrint('Error during BLE scan: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _isScanning = false;
    notifyListeners();
  }

  Future<bool> connectDevice(HRDevice device) async {
    try {
      final bleDevice = BluetoothDevice.fromId(device.id);
      
      // Connect to device
      await bleDevice.connect(timeout: const Duration(seconds: 15));
      
      // Discover services
      List<BluetoothService> services = await bleDevice.discoverServices();
      
      // Find Heart Rate Service
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == hrServiceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == hrMeasurementUuid) {
              // Subscribe to heart rate notifications
              await characteristic.setNotifyValue(true);
              characteristic.value.listen((value) {
                if (value.isNotEmpty) {
                  final heartRate = _parseHeartRate(value);
                  _updateDeviceHeartRate(device.id, heartRate);
                }
              });
            }
          }
        }
        
        // Read battery level if available
        if (service.uuid.toString().toLowerCase() == batteryServiceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == batteryLevelUuid) {
              final value = await characteristic.read();
              if (value.isNotEmpty) {
                device.batteryLevel = value[0];
              }
            }
          }
        }
      }

      device.isConnected = true;
      _connectedDevices.add(device);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      return false;
    }
  }

  Future<void> disconnectDevice(HRDevice device) async {
    try {
      final bleDevice = BluetoothDevice.fromId(device.id);
      await bleDevice.disconnect();
      
      device.isConnected = false;
      device.currentHeartRate = null;
      _connectedDevices.removeWhere((d) => d.id == device.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error disconnecting device: $e');
    }
  }

  int _parseHeartRate(List<int> value) {
    // Parse according to Bluetooth Heart Rate Measurement specification
    // First byte contains flags
    int flags = value[0];
    bool hrFormat = (flags & 0x01) != 0;
    
    if (hrFormat) {
      // Heart rate is in 16-bit format
      return (value[2] << 8) | value[1];
    } else {
      // Heart rate is in 8-bit format
      return value[1];
    }
  }

  void _updateDeviceHeartRate(String deviceId, int heartRate) {
    final deviceIndex = _connectedDevices.indexWhere((d) => d.id == deviceId);
    if (deviceIndex != -1) {
      _connectedDevices[deviceIndex].currentHeartRate = heartRate;
      notifyListeners();
    }
  }

  int? getAverageHeartRate() {
    final rates = _connectedDevices
        .where((d) => d.currentHeartRate != null)
        .map((d) => d.currentHeartRate!)
        .toList();
    
    if (rates.isEmpty) return null;
    return rates.reduce((a, b) => a + b) ~/ rates.length;
  }

  @override
  void dispose() {
    stopScan();
    for (var device in _connectedDevices) {
      disconnectDevice(device);
    }
    super.dispose();
  }
}
