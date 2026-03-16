import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class EmgService {
  // BLE UUIDs for EMG Device
  static const String serviceUuid = "464A3100-5350-6E6F-6974-6F4D74736146";
  static const String commandCharUuid = "464A3101-5350-6E6F-6974-6F4D74736146";
  static const String notifyCharUuid = "464A3102-5350-6E6F-6974-6F4D74736146";
  static const String dataCharUuid = "464A3103-5350-6E6F-6974-6F4D74736146";

  // Command to send
  static final Uint8List deviceInfoCommand =
      Uint8List.fromList([0xF8, 0xF2, 0x0A]);

  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _dataChar;

  // Device info
  String? deviceUuid;
  String? version; // 'S' or 'P'
  String? direction; // 'Left' or 'Right'
  int? threshold;

  // Data stream
  final StreamController<List<int>> _emgDataController =
      StreamController<List<int>>.broadcast();
  Stream<List<int>> get emgDataStream => _emgDataController.stream;

  final StreamController<Map<String, dynamic>> _deviceInfoController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get deviceInfoStream =>
      _deviceInfoController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Scan for EMG devices (MED-S or MED-P)
  Future<BluetoothDevice?> scanForEmgDevice(
      {Duration timeout = const Duration(seconds: 10)}) async {
    BluetoothDevice? foundDevice;

    // Start scanning
    await FlutterBluePlus.startScan(timeout: timeout);

    // Listen to scan results
    final subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.name == 'MED-S' || result.device.name == 'MED-P') {
          foundDevice = result.device;
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });

    // Wait for scan to complete
    await Future.delayed(timeout);
    await subscription.cancel();
    await FlutterBluePlus.stopScan();

    return foundDevice;
  }

  /// Connect to EMG device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _device = device;
      await device.connect(timeout: const Duration(seconds: 15));

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() ==
            serviceUuid.toUpperCase()) {
          for (BluetoothCharacteristic char in service.characteristics) {
            String charUuid = char.uuid.toString().toUpperCase();

            if (charUuid == commandCharUuid.toUpperCase()) {
              _commandChar = char;
            } else if (charUuid == notifyCharUuid.toUpperCase()) {
              _notifyChar = char;
            } else if (charUuid == dataCharUuid.toUpperCase()) {
              _dataChar = char;
            }
          }
        }
      }

      if (_commandChar == null || _notifyChar == null || _dataChar == null) {
        throw Exception('Required characteristics not found');
      }

      _isConnected = true;
      return true;
    } catch (e) {
      print('Error connecting to device: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Request device info
  Future<void> requestDeviceInfo() async {
    if (_commandChar == null || _notifyChar == null) {
      throw Exception('Device not connected or characteristics not found');
    }

    // Subscribe to notify characteristic
    await _notifyChar!.setNotifyValue(true);

    // Listen for device info
    final subscription = _notifyChar!.value.listen((value) {
      if (value.isNotEmpty) {
        _parseDeviceInfo(value);
      }
    });

    // Send command to request device info
    await _commandChar!.write(deviceInfoCommand);

    // Wait a bit for response
    await Future.delayed(const Duration(seconds: 2));
    await subscription.cancel();
  }

  /// Start receiving EMG data
  Future<void> startDataStream() async {
    if (_dataChar == null || threshold == null) {
      throw Exception('Device not ready or device info not retrieved');
    }

    // Subscribe to data characteristic
    await _dataChar!.setNotifyValue(true);

    _dataChar!.value.listen((value) {
      if (value.isNotEmpty) {
        List<int> emgValues = _parseEmgData(value, threshold!);
        _emgDataController.add(emgValues);
      }
    });
  }

  /// Stop receiving EMG data
  Future<void> stopDataStream() async {
    if (_dataChar != null) {
      await _dataChar!.setNotifyValue(false);
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    if (_device != null) {
      await stopDataStream();
      await _device!.disconnect();
      _isConnected = false;
      _device = null;
      _commandChar = null;
      _notifyChar = null;
      _dataChar = null;
    }
  }

  /// Parse device info from bytes
  void _parseDeviceInfo(List<int> rawBytes) {
    try {
      // Find delimiter [0x0A, 0x00, 0x00]
      int delimiterIndex = -1;
      for (int i = 0; i < rawBytes.length - 2; i++) {
        if (rawBytes[i] == 0x0A &&
            rawBytes[i + 1] == 0x00 &&
            rawBytes[i + 2] == 0x00) {
          delimiterIndex = i;
          break;
        }
      }

      if (delimiterIndex == -1) {
        throw Exception('Delimiter not found in device info');
      }

      // Extract UUID (from start to 6 bytes before delimiter)
      List<int> uuidBytes = rawBytes.sublist(0, delimiterIndex - 6);
      deviceUuid = uuidBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join();

      // Extract version (S or P)
      int versionByte = rawBytes[delimiterIndex - 6];
      version = String.fromCharCode(versionByte);

      // Extract direction
      int directionByte = rawBytes[delimiterIndex - 5];
      direction = (directionByte == 48) ? 'Left' : 'Right';

      // Extract threshold (4 ASCII bytes before delimiter)
      List<int> thresholdBytes =
          rawBytes.sublist(delimiterIndex - 4, delimiterIndex);
      String thresholdStr =
          thresholdBytes.map((b) => (b - 48).toString()).join();
      threshold = int.parse(thresholdStr);

      // Emit device info
      _deviceInfoController.add({
        'uuid': deviceUuid,
        'version': version,
        'direction': direction,
        'threshold': threshold,
      });

      print(
          'Device Info - Version: $version, Direction: $direction, Threshold: $threshold');
    } catch (e) {
      print('Error parsing device info: $e');
    }
  }

  /// Parse EMG data from bytes
  List<int> _parseEmgData(List<int> rawBytes, int threshold) {
    // Skip first 5 bytes
    List<int> data = rawBytes.sublist(5);
    List<int> results = [];

    // Read 16-bit little-endian values
    for (int i = 0; i < data.length - 1; i += 2) {
      int value = data[i] + (data[i + 1] << 8);
      int adjustedValue = value - threshold;
      results.add(adjustedValue);
    }

    return results;
  }

  void dispose() {
    _emgDataController.close();
    _deviceInfoController.close();
  }
}
