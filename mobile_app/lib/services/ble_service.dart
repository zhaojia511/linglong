import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hr_device.dart';

class BLEService extends ChangeNotifier {
  final List<HRDevice> _discoveredDevices = [];
  final List<HRDevice> _connectedDevices = [];
  final Map<String, StreamSubscription> _deviceSubscriptions = {};
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;
  bool _permissionsGranted = false;
  static const int maxConnectedDevices = 10;
  
  // Persistence keys
  static const String _lastConnectedDevicesKey = 'last_connected_ble_devices';
  static const String _deviceIdDelimiter = '|';
  
  // Heart Rate Service UUID (Standard Bluetooth SIG)
  static const String hrServiceUuid = "0000180d-0000-1000-8000-00805f9b34fb";
  static const String hrMeasurementUuid = "00002a37-0000-1000-8000-00805f9b34fb";
  static const String batteryServiceUuid = "0000180f-0000-1000-8000-00805f9b34fb";
  static const String batteryLevelUuid = "00002a19-0000-1000-8000-00805f9b34fb";

  BLEService() {
    // Attempt to restore OS-level connected devices after service creation
    Future.microtask(() async {
      try {
        await checkPermissions();
        await _restoreOSConnectedDevices();
      } catch (e) {
        debugPrint('Error during BLEService init: $e');
      }
    });
  }

  List<HRDevice> get discoveredDevices => _discoveredDevices;
  bool get permissionsGranted => _permissionsGranted;
  List<HRDevice> get connectedDevices {
    try {
      // Deduplicate devices by ID to prevent showing duplicates
      final uniqueDevices = <String, HRDevice>{};
      for (var device in _connectedDevices) {
        uniqueDevices[device.id] = device;
      }
      final deduped = uniqueDevices.values.toList();
      
      if (deduped.length != _connectedDevices.length) {
        debugPrint('WARNING: Removed ${_connectedDevices.length - deduped.length} duplicate devices!');
        // Clean up the internal list
        _connectedDevices.clear();
        _connectedDevices.addAll(deduped);
      }
      
      debugPrint('Getting connectedDevices - Count: ${deduped.length}');
      for (var i = 0; i < deduped.length; i++) {
        debugPrint('  Device $i: ${deduped[i].id} (${deduped[i].name})');
      }
      return deduped;
    } catch (e) {
      debugPrint('Error getting connected devices: $e');
      return [];
    }
  }
  bool get isScanning => _isScanning;

  Future<bool> isBluetoothAvailable() async {
    try {
      return await FlutterBluePlus.isAvailable;
    } catch (e) {
      debugPrint('Error checking Bluetooth availability: $e');
      return false;
    }
  }

  Future<bool> checkPermissions() async {
    // On iOS, Bluetooth permissions cannot be checked programmatically
    // We assume they're granted and rely on BLE operations to fail if not
    if (Platform.isIOS) {
      if (!_permissionsGranted) {
        _permissionsGranted = true;
        notifyListeners();
      }
      return true;
    }

    // On Android and other platforms, check permissions normally
    final statuses = await Future.wait([
      Permission.bluetooth.status,
      Permission.bluetoothScan.status,
      Permission.bluetoothConnect.status,
      Permission.location.status,
    ]);
    final granted = statuses.every((status) => status.isGranted);
    if (_permissionsGranted != granted) {
      _permissionsGranted = granted;
      notifyListeners();
    }
    return granted;
  }

  /// Restore any OS-level connected devices that the platform reports
  /// This helps when the app crashed or was force-quit but the OS still
  /// considers the BLE peripheral connected and it won't advertise during scans.
  Future<void> _restoreOSConnectedDevices() async {
    try {
      debugPrint('Attempting to restore OS-level connected devices...');
      final osDevices = FlutterBluePlus.connectedDevices;
      if (osDevices.isEmpty) {
        debugPrint('No OS-level connected devices found');
        return;
      }

      for (final bd in osDevices) {
        try {
          final deviceId = bd.id.toString();
          if (_connectedDevices.any((d) => d.id == deviceId)) continue;

          final hrDevice = HRDevice(
            id: deviceId,
            name: bd.name.isNotEmpty ? bd.name : 'Unknown Device',
            address: deviceId,
            rssi: 0,
          );

          // Attempt to subscribe to HR notifications on this device
          final success = await connectDevice(hrDevice);
          if (success) {
            debugPrint('Restored connection to OS device: $deviceId');
          } else {
            debugPrint('Failed to restore connection to OS device: $deviceId');
          }
        } catch (e) {
          debugPrint('Error restoring device: $e');
        }
      }
    } catch (e) {
      debugPrint('Error while restoring OS connected devices: $e');
    }
  }

  /// Public accessor to load saved connected devices (from prefs)
  Future<List<HRDevice>> getSavedConnectedDevices() async {
    return await _loadSavedConnectedDevices();
  }

  // forceReconnect removed: operation deprecated because it didn't improve discovery

  Future<bool> requestPermissions() async {
    // On iOS, Bluetooth permissions cannot be requested programmatically
    // We assume they're granted and rely on BLE operations to fail if not
    if (Platform.isIOS) {
      if (!_permissionsGranted) {
        _permissionsGranted = true;
        notifyListeners();
      }
      return true;
    }

    // On Android and other platforms, request permissions normally
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    final granted = statuses.values.every((status) => status.isGranted);
    if (_permissionsGranted != granted) {
      _permissionsGranted = granted;
      notifyListeners();
    }
    return granted;
  }

  Future<String?> startScan() async {
    if (_isScanning) return null;

    try {
      // Check cached permissions first
      if (!_permissionsGranted) {
        final hasPermission = await requestPermissions();
        if (!hasPermission) {
          debugPrint('Bluetooth permissions not granted');
          return 'Bluetooth permissions not granted. Please enable permissions in settings.';
        }
      }

      // Double-check Bluetooth availability
      if (await FlutterBluePlus.isAvailable == false) {
        debugPrint("Bluetooth not available");
        return 'Bluetooth is disabled. Please enable Bluetooth in device settings.';
      }

      // Stop any existing scan and clear old results
      try {
        await FlutterBluePlus.stopScan();
        await _scanSubscription?.cancel();
        _scanSubscription = null;
      } catch (e) {
        debugPrint('Error stopping previous scan: $e');
      }

      _discoveredDevices.clear();
      _isScanning = true;
      notifyListeners();

      // Small delay to let Bluetooth stack reset
      await Future.delayed(const Duration(milliseconds: 300));

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [Guid(hrServiceUuid)], // Only scan for HR devices
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        try {
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
              debugPrint('Discovered device: ${device.id} (${device.name}) RSSI: ${result.rssi}');
              notifyListeners();
            }
          }
        } catch (e) {
          debugPrint('Error processing scan results: $e');
        }
      });

      // Auto stop scanning after timeout
      await Future.delayed(const Duration(seconds: 15));
      await stopScan();
      return null;
    } catch (e) {
      debugPrint('Error during BLE scan: $e');
      _isScanning = false;
      notifyListeners();

      // Check if this is a permission-related error on iOS
      final errorString = e.toString().toLowerCase();
      if (Platform.isIOS && (errorString.contains('permission') || errorString.contains('denied') || errorString.contains('unauthorized'))) {
        _permissionsGranted = false;
        notifyListeners();
        return 'Bluetooth permissions not granted. Please enable permissions in Settings > Privacy & Security > Bluetooth.';
      }

      return 'Failed to scan: ${e.toString()}';
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
      // Validate device ID
      if (device.id.isEmpty) {
        debugPrint('Cannot connect device with empty ID');
        return false;
      }

      // Check if max devices already connected
      if (_connectedDevices.length >= maxConnectedDevices) {
        debugPrint('Maximum number of devices already connected: $maxConnectedDevices');
        return false;
      }

      final bleDevice = BluetoothDevice.fromId(device.id);
      
      // Connect to device if it's not already connected at the OS level
      final osConnected = FlutterBluePlus.connectedDevices;
      final alreadyConnectedAtOS = osConnected.any((d) => d.id.toString() == bleDevice.id.toString());
      if (!alreadyConnectedAtOS) {
        // Connect to device
        await bleDevice.connect(timeout: const Duration(seconds: 15));
      } else {
        debugPrint('Device ${device.id} already connected at OS level; skipping connect()');
      }

      // Discover services (works whether we called connect() or not)
      List<BluetoothService> services = await bleDevice.discoverServices();
      
      // Find Heart Rate Service
      for (BluetoothService service in services) {
        debugPrint('Found service: ${service.uuid}');
        if (service.uuid.toString().toLowerCase().contains('180d')) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            debugPrint('Found characteristic: ${characteristic.uuid}');
            if (characteristic.uuid.toString().toLowerCase().contains('2a37')) {
              // Enable notifications first, then subscribe
              await characteristic.setNotifyValue(true);
              
              // Subscribe to value updates and store subscription for cleanup
              final subscription = characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  final heartRate = _parseHeartRate(value);
                  debugPrint('Heart rate received from ${device.id}: $heartRate bpm');
                  _updateDeviceHeartRate(device.id, heartRate);
                  
                  // Try to parse RR intervals (HRV data)
                  final rrIntervals = _parseRRIntervals(value);
                  if (rrIntervals != null && rrIntervals.isNotEmpty) {
                    debugPrint('RR intervals received from ${device.id}: ${rrIntervals.length} intervals');
                    _updateDeviceRRIntervals(device.id, rrIntervals);
                  }
                }
              });
              
              _deviceSubscriptions[device.id] = subscription;
              debugPrint('Subscribed to heart rate notifications from ${device.id}');
            }
          }
        }
        
        // Read battery level if available
        if (service.uuid.toString().toLowerCase().contains('180f')) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains('2a19')) {
              try {
                final value = await characteristic.read();
                if (value.isNotEmpty) {
                  device.batteryLevel = value[0];
                  debugPrint('Battery level from ${device.id}: ${device.batteryLevel}%');
                }
              } catch (e) {
                debugPrint('Could not read battery level from ${device.id}: $e');
              }
            }
          }
        }
      }

      device.isConnected = true;
      _connectedDevices.add(device);
      debugPrint('Successfully connected to device: ${device.id}');
      debugPrint('Total connected devices now: ${_connectedDevices.length}');
      for (var i = 0; i < _connectedDevices.length; i++) {
        debugPrint('  Device $i: ${_connectedDevices[i].id} (${_connectedDevices[i].name})');
      }

      // Save connected device to persistent storage
      await _saveConnectedDevices();

      // Monitor connection state
      final connectionSubscription = bleDevice.connectionState.listen((state) {
        debugPrint('Connection state changed for ${device.id}: $state');
        if (state == BluetoothConnectionState.disconnected) {
          // Device disconnected, update status
          final deviceIndex = _connectedDevices.indexWhere((d) => d.id == device.id);
          if (deviceIndex != -1) {
            _connectedDevices[deviceIndex].isConnected = false;
            _connectedDevices[deviceIndex].currentHeartRate = null;
            _connectedDevices[deviceIndex].rrIntervals = null;
            debugPrint('Device ${device.id} marked as disconnected');
            notifyListeners();
          }
        } else if (state == BluetoothConnectionState.connected) {
          // Device reconnected
          final deviceIndex = _connectedDevices.indexWhere((d) => d.id == device.id);
          if (deviceIndex != -1) {
            _connectedDevices[deviceIndex].isConnected = true;
            debugPrint('Device ${device.id} reconnected');
            notifyListeners();
          }
        }
      });

      // Store connection subscription for cleanup
      _deviceSubscriptions['${device.id}_connection'] = connectionSubscription;

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      device.isConnected = false;
      return false;
    }
  }

  Future<void> disconnectDevice(HRDevice device) async {
    try {
      final bleDevice = BluetoothDevice.fromId(device.id);
      
      // Cancel subscriptions for this device BEFORE disconnecting
      _deviceSubscriptions[device.id]?.cancel();
      _deviceSubscriptions.remove(device.id);
      _deviceSubscriptions['${device.id}_connection']?.cancel();
      _deviceSubscriptions.remove('${device.id}_connection');
      
      // Disconnect from device
      await bleDevice.disconnect();
      
      // Wait a moment for the device to fully disconnect and start advertising again
      await Future.delayed(const Duration(milliseconds: 500));
      
      device.isConnected = false;
      device.currentHeartRate = null;
      device.rrIntervals = null;
      _connectedDevices.removeWhere((d) => d.id == device.id);
      debugPrint('Disconnected from device: ${device.id}');
      debugPrint('Total connected devices now: ${_connectedDevices.length}');
      
      // Update persistence
      await _saveConnectedDevices();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error disconnecting device: $e');
      // Even if disconnect fails, clean up local state
      _deviceSubscriptions[device.id]?.cancel();
      _deviceSubscriptions.remove(device.id);
      _deviceSubscriptions['${device.id}_connection']?.cancel();
      _deviceSubscriptions.remove('${device.id}_connection');
      device.isConnected = false;
      _connectedDevices.removeWhere((d) => d.id == device.id);
      await _saveConnectedDevices();
      notifyListeners();
    }
  }

  Future<void> disconnectAllDevices() async {
    final devicesCopy = List<HRDevice>.from(_connectedDevices);
    for (var device in devicesCopy) {
      await disconnectDevice(device);
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

  List<int>? _parseRRIntervals(List<int> value) {
    // Parse RR intervals from Heart Rate Measurement characteristic
    // Format: Flags (1 byte) + HR (1-2 bytes) + [optional RR intervals (2 bytes each)]
    // Bit 4 of flags indicates if RR interval data is present
    if (value.isEmpty) return null;
    
    int flags = value[0];
    bool hasRRIntervals = (flags & 0x10) != 0;
    
    if (!hasRRIntervals) return null;
    
    bool hrFormat = (flags & 0x01) != 0;
    int hrBytes = hrFormat ? 2 : 1;
    int startIndex = 1 + hrBytes; // Skip flags and HR value
    
    if (value.length <= startIndex) return null;
    
    List<int> rrIntervals = [];
    // Parse RR intervals (each is 2 bytes, little-endian)
    for (int i = startIndex; i + 1 < value.length; i += 2) {
      int rrValue = (value[i + 1] << 8) | value[i];
      rrIntervals.add(rrValue);
    }
    
    return rrIntervals.isNotEmpty ? rrIntervals : null;
  }

  void _updateDeviceHeartRate(String deviceId, int heartRate) {
    final deviceIndex = _connectedDevices.indexWhere((d) => d.id == deviceId);
    if (deviceIndex != -1) {
      _connectedDevices[deviceIndex].currentHeartRate = heartRate;
      notifyListeners();
    }
  }

  void _updateDeviceRRIntervals(String deviceId, List<int> rrIntervals) {
    final deviceIndex = _connectedDevices.indexWhere((d) => d.id == deviceId);
    if (deviceIndex != -1) {
      _connectedDevices[deviceIndex].rrIntervals = rrIntervals;
      _connectedDevices[deviceIndex].supportsHRV = true;
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
    disconnectAllDevices();
    for (var subscription in _deviceSubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  // Reset service state for app restart
  void reset() {
    debugPrint('Resetting BLE service state');
    stopScan();
    disconnectAllDevices();
    _discoveredDevices.clear();
    _connectedDevices.clear();
    _deviceSubscriptions.clear();
    _isScanning = false;
    _permissionsGranted = false;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    notifyListeners();
  }

  /// Save currently connected device IDs to persistent storage
  Future<void> _saveConnectedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final connectedIds = _connectedDevices
          .map((d) => '${d.id}$_deviceIdDelimiter${d.name}$_deviceIdDelimiter${d.address}')
          .toList();
      await prefs.setStringList(_lastConnectedDevicesKey, connectedIds);
      debugPrint('Saved ${connectedIds.length} connected devices to persistence');
    } catch (e) {
      debugPrint('Error saving connected devices: $e');
    }
  }

  /// Restore previously connected device IDs from persistent storage
  Future<List<HRDevice>> _loadSavedConnectedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDeviceStrings = prefs.getStringList(_lastConnectedDevicesKey) ?? [];
      
      if (savedDeviceStrings.isEmpty) {
        debugPrint('No saved connected devices found');
        return [];
      }

      final savedDevices = <HRDevice>[];
      for (final deviceString in savedDeviceStrings) {
        final parts = deviceString.split(_deviceIdDelimiter);
        if (parts.length >= 3) {
          savedDevices.add(HRDevice(
            id: parts[0],
            name: parts[1],
            address: parts[2],
            rssi: 0, // Default RSSI value for saved devices
          ));
        }
      }
      debugPrint('Loaded ${savedDevices.length} saved connected devices');
      return savedDevices;
    } catch (e) {
      debugPrint('Error loading saved connected devices: $e');
      return [];
    }
  }

  /// Auto-reconnect to previously connected devices
  Future<void> autoReconnectToSavedDevices() async {
    try {
      debugPrint('Attempting to auto-reconnect to previously connected devices...');
      
      // Check permissions first
      if (!_permissionsGranted) {
        final hasPermission = await checkPermissions();
        if (!hasPermission) {
          debugPrint('Permissions not granted, skipping auto-reconnect');
          return;
        }
      }

      // Load saved devices
      final savedDevices = await _loadSavedConnectedDevices();
      if (savedDevices.isEmpty) {
        debugPrint('No saved devices to reconnect to');
        return;
      }

      // Attempt to reconnect to each saved device
      debugPrint('Auto-reconnecting to ${savedDevices.length} saved device(s)...');
      for (final device in savedDevices) {
        try {
          debugPrint('Auto-reconnecting to device: ${device.id}');
          await connectDevice(device);
        } catch (e) {
          debugPrint('Failed to auto-reconnect to device ${device.id}: $e');
          // Continue trying other devices
        }
      }
    } catch (e) {
      debugPrint('Error during auto-reconnect: $e');
    }
  }
}
