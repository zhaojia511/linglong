# HRV (Heart Rate Variability) Support Implementation

## Overview
Added HRV support to the Linglong app to capture RR interval data from compatible HR sensors like the HRM508. This enables future HRV analysis features.

## Changes Made

### 1. HRDevice Model (`mobile_app/lib/models/hr_device.dart`)
Added HRV-related fields to track sensor capabilities:
- `rrIntervals`: List of RR intervals in milliseconds (for HRV analysis)
- `supportsHRV`: Boolean flag indicating if the device supports HRV data transmission

### 2. BLE Service (`mobile_app/lib/services/ble_service.dart`)
Enhanced to parse and handle RR interval data:

#### New Methods
- `_parseRRIntervals(List<int> value)`: Parses RR interval data from the BLE Heart Rate Measurement characteristic
- `_updateDeviceRRIntervals(String deviceId, List<int> rrIntervals)`: Updates device with RR interval data

#### Enhanced Methods
- `connectDevice()`: Now detects RR interval support on connection
- Heart rate subscription listener: Now extracts both HR and RR intervals from characteristic data

#### Data Format (Bluetooth HRM Specification)
The Heart Rate Measurement characteristic (0x2A37) contains:
```
Byte 0: Flags
  - Bit 0: HR format (0=8-bit, 1=16-bit)
  - Bit 4: RR interval data present (0=absent, 1=present)
Byte 1-2: Heart Rate value (8 or 16 bits)
Byte 3+: RR intervals (2 bytes each, little-endian, if present)
```

### 3. ESP32C3 HR Emulator Sketch (`hardware/hr_emulator/hr_emulator.ino`)
Updated to broadcast HRV data alongside HR:

#### Features
- Sends Heart Rate value (8-bit format)
- Sends 3 RR interval samples per notification
- Calculates RR intervals from current BPM: `RR (ms) = 60000 / HR`
- Adds realistic jitter to RR intervals (±20ms) to simulate natural variability

#### Payload Structure
```
Byte 0: 0x10 (flags: RR intervals present, 8-bit HR format)
Byte 1: HR value (bpm)
Byte 2-3: RR interval 1 (little-endian)
Byte 4-5: RR interval 2 (little-endian)
Byte 6-7: RR interval 3 (little-endian)
```

---

## Verifying HRM508 HRV Support

### Method 1: Check Characteristic Data on Connection
The app now logs when RR interval data is detected:
```
I/flutter: RR intervals received from <device_id>: 3 intervals
```

### Method 2: Use Flutter's BLE Debug Logs
Monitor the Dart console during connection:
- Look for "RR intervals received" messages
- Check if device has `supportsHRV = true` in debugger

### Method 3: Analyze Raw BLE Data
If HRM508 sends RR intervals, the characteristic value will have:
- Flags byte with bit 4 set (0x10 or higher)
- 3 RR interval values (2 bytes each)

### Method 4: Visual Inspection in App
When RR interval data is available:
- Dashboard will detect HRV support automatically
- Device model will have `supportsHRV = true`
- RR intervals will be stored and available for analysis

---

## How HRM508 Should Broadcast HRV

For the HRM508 to be detected as HRV-capable:

1. **Send Heart Rate Measurement characteristic (0x2A37)** with:
   - Flags byte with bit 4 set (RR interval data present)
   - HR value (8 or 16-bit)
   - One or more RR intervals (2 bytes each, little-endian)

2. **Example RR intervals** if HR = 80 bpm:
   - Expected RR ≈ 750 ms (60000/80)
   - Actual values might vary: 745ms, 752ms, 748ms (with natural variability)

---

## Testing

### Test 1: With ESP32C3 Emulator (Updated)
1. Flash the updated `hr_emulator.ino` to ESP32C3
2. Connect to "Linglong HR Emulator" in the app
3. Monitor logs for: `RR intervals received from <device_id>: 3 intervals`
4. Verify device has `supportsHRV = true`

### Test 2: With HRM508 Real Sensor
1. Connect to HRM508
2. Monitor app logs for HRV detection
3. If logs show RR intervals, HRM508 supports HRV ✓
4. If no RR intervals, HRM508 may only send HR data

### Test 3: Verify Data Format
Check the BLE characteristic values in debug output:
```
Raw bytes: [0x10, 0x50, 0xE8, 0x02, 0xEA, 0x02, 0xE9, 0x02]
Flags: 0x10 (RR intervals present)
HR: 80 bpm
RR1: 0x02E8 = 744 ms
RR2: 0x02EA = 746 ms
RR3: 0x02E9 = 745 ms
```

---

## Next Steps

1. **Verify HRM508 Output**: Run the app connected to HRM508 and check console logs
2. **If HRV Data Found**: 
   - Data is now captured and stored
   - Ready for future HRV analysis features
3. **If No HRV Data**:
   - HRM508 may only support basic HR (no RR intervals)
   - App will still work, just without HRV metrics
   - Can add proprietary sensor profile if needed

---

## Technical Notes

- **RR Interval Units**: Milliseconds (ms), standard Bluetooth specification
- **Typical HRV Range**: RR intervals vary by ±5-50ms in healthy individuals
- **Parsing Logic**: Handles both 8-bit and 16-bit HR formats, variable number of RR samples
- **Device Support**: Works with any Bluetooth HR sensor following the standard specification
- **Backward Compatible**: Non-HRV sensors still work normally, just `supportsHRV` stays false

---

## References

- **Bluetooth Heart Rate Profile**: UUID 0x180D (Service), 0x2A37 (Characteristic)
- **Heart Rate Measurement Format**: Section 3.45 of Bluetooth Core Specification Supplement
- **RR Interval (HRV)**: Standard metric for heart rate variability analysis (Task Force 1996)
