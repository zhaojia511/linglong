# Mobile App Updates - Multi HR Sensor & Dashboard UI Redesign

## Summary
Updated the mobile app to support connecting multiple HR sensors via BLE and redesigned the dashboard with smaller, square-shaped device cards arranged in a 2-column grid layout.

## Changes Made

### 1. BLE Service Enhancements (`lib/services/ble_service.dart`)

#### Multi-Device Support
- Added `maxConnectedDevices` constant (max 10 devices) with validation
- Added `_deviceSubscriptions` map to track and manage subscriptions for each device
- Implemented `disconnectAllDevices()` method for bulk disconnection
- Enhanced device connection validation to prevent duplicate connections
- Added connection limit check before allowing new device connections

#### Improved Device Lifecycle Management
- Better subscription cleanup per device with unique tracking via device ID
- Enhanced debug logging with device IDs for easier troubleshooting
- Proper cleanup in `dispose()` method for all subscriptions

#### Key Methods Updated
- `connectDevice()`: Now checks connection limits and prevents duplicate connections
- `disconnectDevice()`: Properly cancels device-specific subscriptions
- `disconnectAllDevices()`: New method to disconnect all devices at once
- Heart rate updates now include device-specific logging

---

### 2. Dashboard UI Redesign (`lib/screens/dashboard_screen.dart`)

#### Grid Layout Implementation
- Changed from vertical list to **2-column GridView** layout
- Cards are now **square-shaped** (1:1 aspect ratio) for compact display
- Reduced padding and spacing (12px instead of 16px) for better space efficiency
- Smaller font sizes throughout for compact display

#### New Square Card Design (`_buildSquareDeviceCard()`)
Features:
- **Gradient background** for visual appeal
- **Compact member avatar** at top (radius 20 instead of 30)
- **Centered heart rate display** with color-coded background
- **Device name and battery info** at bottom
- **Mini stats** (Avg/Max/Min) when recording, displayed in tiny boxes
- Better visual hierarchy with vertical spacing

#### Enhanced Device Dialog
- Shows connected device count (e.g., "Connected: 5/10")
- Added "Rescan" button for convenience
- Improved connection feedback with success/failure snackbars
- Shows lock icon when max devices reached
- New "Disconnect All" button for bulk management
- Better visual indicators for connection status

#### Key Features
1. **Space Optimization**: Cards are now ~40% smaller with 2-column layout
2. **Visual Consistency**: All cards have consistent styling with gradient backgrounds
3. **Better Data Display**: Mini stats in compact format when recording
4. **Improved UX**: 
   - Connection limit indicator (e.g., "5/10 devices")
   - Instant feedback for connection attempts
   - Easy disconnect all option

---

## Technical Details

### Device Connection Flow
1. Scan for devices (filtered to HR service UUID only)
2. Display discovered devices in dialog
3. Click "Connect" to establish connection (max 10 devices)
4. Automatic heart rate subscription per device
5. Battery level read on connection
6. Device-specific data tracking during training sessions

### Dashboard Display Logic
- When no devices connected: Shows placeholder message
- When devices connected: Displays in 2×N grid
- Each card shows:
  - Member number (colored circle)
  - Current heart rate with color-coded background
  - Device name and battery level
  - Avg/Max/Min stats (when recording)

### Data Tracking
- `_heartRateHistoryByDevice`: Tracks data per device ID
- Training sessions store device-specific heart rate data
- Multiple devices can record simultaneously

---

## File Changes Summary

### Modified Files
1. **`lib/services/ble_service.dart`**
   - Enhanced with multi-device support
   - Better subscription management
   - Connection limit validation

2. **`lib/screens/dashboard_screen.dart`**
   - Grid-based card layout instead of list
   - Smaller square cards with new design
   - Enhanced device management dialog
   - Improved UX with connection feedback

---

## Usage Notes

### Connecting Multiple Devices
1. Tap Bluetooth icon
2. Tap "Rescan" to find devices
3. Click "Connect" on each device (max 10)
4. All devices will stream heart rate data simultaneously
5. Use "Disconnect All" to disconnect all at once

### Dashboard
- Devices appear in compact 2-column grid
- Heart rate color changes based on intensity:
  - Blue: < 60 bpm
  - Green: 60-99 bpm
  - Orange: 100-139 bpm
  - Red: ≥ 140 bpm

### Recording Training Sessions
- Start recording when devices connected
- Stats (Avg/Max/Min) update in real-time for each device
- All device data saved to training session

---

## Benefits

✅ Support for up to 10 simultaneous HR sensors  
✅ Compact dashboard with better space utilization  
✅ Improved multi-device management  
✅ Better visual feedback and UX  
✅ Easier team monitoring  
✅ Device-specific data tracking  

---

## Future Enhancements

- Add device filtering/search in dialog
- Custom device naming
- Device connection preferences saving
- Advanced analytics per device
- Alert thresholds per device
