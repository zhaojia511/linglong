# EMG Feature Documentation

## Overview
The EMG module provides Bluetooth Low Energy (BLE) connectivity and real-time visualization for EMG (Electromyography) sensors.

## Files Created

### 1. `lib/services/emg_service.dart`
BLE service for EMG device communication:
- **Device discovery**: Scans for MED-S or MED-P devices
- **Connection management**: Connect/disconnect functionality
- **Device info retrieval**: Parses device version, direction, threshold
- **Data streaming**: Real-time EMG data collection and parsing

### 2. `lib/screens/emg_screen.dart`
UI screen for EMG monitoring:
- Connection controls (scan, connect, disconnect)
- Start/stop data streaming
- Real-time chart visualization using fl_chart
- Device info display (version, direction, threshold)

## BLE Specification

### Service UUID
`464A3100-5350-6E6F-6974-6F4D74736146`

### Characteristics
- **Command**: `464A3101-5350-6E6F-6974-6F4D74736146`
  - Write device info command: `[0xF8, 0xF2, 0x0A]`
- **Notify**: `464A3102-5350-6E6F-6974-6F4D74736146`
  - Receives device info (version, direction, threshold)
- **Data**: `464A3103-5350-6E6F-6974-6F4D74736146`
  - Receives real-time EMG data stream

## Data Parsing

### Device Info Format
- Delimiter: `[0x0A, 0x00, 0x00]`
- UUID: Bytes from start to 6 bytes before delimiter
- Version: 1 byte (ASCII 'S' or 'P')
- Direction: 1 byte (48 = Left, otherwise Right)
- Threshold: 4 ASCII bytes converted to integer

### EMG Data Format
- Skip first 5 bytes
- Read 16-bit little-endian values (2 bytes per sample)
- Subtract threshold from each value
- Returns adjusted EMG values

## Integration

### Add to Navigation
Update your main navigation (e.g., in `home_screen.dart` or drawer) to include:

```dart
import 'screens/emg_screen.dart';

// In your navigation menu:
ListTile(
  leading: Icon(Icons.waves),
  title: Text('EMG Monitor'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EmgScreen()),
    );
  },
),
```

### Dependencies
Required packages (already in pubspec.yaml):
- `flutter_blue_plus`: ^1.31.0 (BLE connectivity)
- `fl_chart`: ^0.65.0 (Chart visualization)

## Usage

1. Open the EMG Monitor screen
2. Click "Connect" to scan and connect to an EMG device
3. Once connected, device info is automatically retrieved
4. Click "Start" to begin streaming EMG data
5. View real-time signal on the chart
6. Click "Stop" to pause streaming
7. Click "Disconnect" to disconnect from the device

## Next Steps

- Add data export/save functionality
- Implement signal filtering (bandpass, notch)
- Add session recording and history
- Integrate with backend for cloud storage
- Add analytics and statistics displays
